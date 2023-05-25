
import boto3
import logging
from boto3.dynamodb.conditions import Key
import json
import configparser
import time
import yaml
import logging.config
from threading import Thread

from template import execution
import utils

debug = False
if debug:
    boto3.setup_default_session(profile_name='workers')

config = configparser.ConfigParser()
config.read('manager.ini') # userdata

boto3.setup_default_session(region_name=config['DEFAULT']['region'])

with open('logging_config.yaml') as log_config:
    config_yml = log_config.read()
    config_dict = yaml.safe_load(config_yml)
    logging.config.dictConfig(config_dict)
    logger = logging.getLogger()


lambda_arn_workers_manager = config['DEFAULT']['lambda_arn_workers_manager']
lambdaclient = boto3.client('lambda')
#table = boto3.resource('dynamodb').Table('tasks') 
asgclient = boto3.client('autoscaling')
s3client = boto3.client('s3')
sqsclient = boto3.resource('sqs')
ec2 = boto3.client('ec2')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tasks') 
    
instanceID = None
eips = None
stop_t_watcher = False

def is_the_task_set_to_terminate(taskID):
    statusT = None
    #try:
    response = table.query(
        KeyConditionExpression=Key('taskID').eq(taskID),
        Select='SPECIFIC_ATTRIBUTES',
        ProjectionExpression='StatusT,taskID',
    )
    if response and response['Count'] > 0:
        
        statusT = response['Items'][0]['StatusT']
        print(f"StatusT: {statusT}")
        if statusT == "INTERRUPT":
            return True
    return False
    # except:
    #     pass


def termination_watcher(taskID,tmp_folder):
    global stop_t_watcher
    while True:
        time.sleep(30)
        print("checking if the task is set to be terminated")
        if is_the_task_set_to_terminate(taskID):
            proc_ids = utils.read_all_proc_ids(tmp_folder)
            if proc_ids:
                for proc_id in proc_ids:
                    print(f"Killing container: {proc_id}")
                    cmd=("docker kill "+proc_id).split(' ')
                    print(" ".join(cmd))
                    utils.kill_proc(cmd)
                utils.garbage_collector(tmp_folder)
                break
        print(f"stop_t_watcher: {stop_t_watcher}")
        if stop_t_watcher:
            break
            
                    

def getAvailableEIP():
    availableEIPs = []
    addresses_dict = ec2.describe_addresses()
    for eip_dict in addresses_dict['Addresses']:
        #if "InstanceId" not in eip_dict:
        #print (eip_dict['PublicIp'] + " doesn't have any instances associated")
        availableEIPs.append(eip_dict['PublicIp'])     
        
    return availableEIPs

def notify_lambda_function(notification):
    response = lambdaclient.invoke(
        FunctionName=lambda_arn_workers_manager,
        LogType='None',
        Payload=json.dumps(notification)
    )
    response = str(response['Payload'].read())
    print(response)


def get_my_EC2instance_status():
    try:
        print(instanceID)
        response = asgclient.describe_auto_scaling_instances(
            InstanceIds=[ instanceID ]
        )
        print(response['AutoScalingInstances'][0]['LifecycleState'])
        return response['AutoScalingInstances'][0]['LifecycleState']
    except IndexError:
        pass
    return False

def start():
    global instanceID
    global eips
    instanceID = utils.get_instance_id()
    eips = getAvailableEIP()


    # Notify that I am available
    notification = {'type':'worker','hostname':instanceID,'online':'ONLINE'}
    notify_lambda_function(notification)
    fetch_queue_msg()


def fetch_queue_msg():    

    try:
        
        while True:
            # when the autoscaling group mark this machine to be terminated, this check if the python script should continue reading tasks or simply let the ec2 instance be terminated.
            if get_my_EC2instance_status() == "Terminating:Wait":
                print("Ready to terminate")
                # aws autoscaling complete-lifecycle-action --lifecycle-hook-name asg-terminate-hook --auto-scaling-group-name asg --lifecycle-action-result ABANDON --instance-id i-066cecbc502fcadf2  --region us-east-1
                response = asgclient.complete_lifecycle_action(
                    LifecycleHookName='asg-terminate-hook',
                    AutoScalingGroupName='asg',
                    LifecycleActionResult='ABANDON',
                    InstanceId=instanceID
                )
                exit(0)

            else:
                queue = sqsclient.get_queue_by_name(QueueName='tasks-queue') # , region_name=config['DEFAULT']['region']



                for message in queue.receive_messages():
                    # messages = sqs.receive_messages(
                    #     MessageAttributeNames=['All'],
                    #     MaxNumberOfMessages=10,
                    #     WaitTimeSeconds=10
                    # )

                    msg = json.loads(message.body)
                    print('Task, {0}'.format(message.body))
                    #if debug is not True:
                    
                    #print(msg)
                    payload = json.loads(msg['Message'])
                    _message =payload['message']
                    passwd = payload['passwd']
                    taskID = payload['taskID']
                    s3folder = payload['s3folder']
                    UID = payload['UID']
        
                    message.delete()
                    try:

                        # continue as long as my public ip is part of the eip pool or the eip pool is 0
                        if utils.getMyPublicIP() in eips or len(eips) == 0:
                
                            notification = {'type':'tasks','taskID':taskID,'StatusT':'RUNNING', 'Worker':instanceID, 'UID':UID}
                            notify_lambda_function(notification)

                            

                            run_task(taskID, s3folder, passwd, _message, UID)

                            # Once the scan is completed: This will triger a set of actions, fetch task, delete task, put task in archive.
                            notification = {'type':'tasks','taskID':taskID,'StatusT':'COMPLETED', 'Worker':instanceID}
                            notify_lambda_function(notification)

                        else:
                            #message.delete()
                            # for some reason the instance is using a dynamic IP address when there are EIP available.
                            notification = {'type':'tasks','taskID':taskID,'StatusT':'ERROR-01', 'Worker':instanceID}
                            notify_lambda_function(notification)
                            #print()

                    except Exception as e:
                        #message.delete()
                        notification = {'type':'tasks','taskID':taskID,'StatusT':'ERROR', 'Worker':instanceID}
                        notify_lambda_function(notification)
                        logger.debug(e,exc_info=True)

            time.sleep(2)

    except KeyboardInterrupt:
        print('interrupted!')
    except Exception as e:
        #notification = {'type':'tasks','taskID':taskID,'StatusT':'ERROR', 'Worker':instanceID}
        #notify_lambda_function(notification)
        logger.debug(e,exc_info=True)


def run_task(taskID, s3folder, passwd, _message, UID):
    global stop_t_watcher
    try:
        print(f"starting task: {taskID}, user {UID}")
        _message = json.loads(_message)
        if 'domain' not in _message:
            raise Exception('Domain is not present')
            
        domain = _message['domain']
        print(f"domain: {domain}")
        
        tmp_folder = utils.create_tmp_folder()
        
        print(f"passwd: {passwd}")
        print(f"Folder: {tmp_folder}")

        utils.create_proc_ids_folder(tmp_folder)

        cloudwatch_docker_logs = f"--log-driver=awslogs --log-opt awslogs-region={config['DEFAULT']['region']} --log-opt awslogs-stream=execution --log-opt awslogs-group=/aws/ec2/ec2pyDockerLogs_{UID}_{taskID}"
        cid_file_docker_param = f"--cidfile {tmp_folder}procIDs/{utils.get_random_string()}.txt"
        extra_docker_params = f"{cid_file_docker_param} {cloudwatch_docker_logs}"

        
        t_watcher = Thread(target = termination_watcher, args = (taskID,tmp_folder, ))
        t_watcher.start()

        exec = Thread(target = execution, args = (tmp_folder, domain, extra_docker_params,  ))
        exec.start()
        exec.join()
        stop_t_watcher = True
        print("thread exec back")

        t_watcher.join()

        #execution(tmp_folder, domain, extra_docker_params)


        compress_pathfile = utils.compress_folder(tmp_folder)
        output_pathfile_enc = utils.encrypt_file(passwd, compress_pathfile)

        print(s3folder)
        # Upload the file
        response = s3client.upload_file(output_pathfile_enc, config['DEFAULT']['s3bucket_name_results_storage'], f'{s3folder}/compress_and_encrypted.tar.gz.enc', 
            ExtraArgs={"Tagging": 'Key=Report'})
        utils.remove_tmp_folder(tmp_folder)
             
    except Exception as e:
        notification = {'type':'tasks','taskID':taskID,'StatusT':'ERROR', 'Worker':instanceID}
        notify_lambda_function(notification)
        logger.debug(e,exc_info=True)




# notification = {'type':'tasks','taskID':'a83a9fe2-9610-46d9-9503-53cac71f6c94','StatusT':'COMPLETED', 'Worker':instanceID}
# notify_lambda_function(notification)

