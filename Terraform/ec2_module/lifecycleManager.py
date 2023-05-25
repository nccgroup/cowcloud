import json
import boto3
import os
import uuid
import traceback
import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

ec2 = boto3.client('ec2')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('workers')

def main(event, context):
    print("Hello from lifecyclemanager.py! testing")

    try:
        #print(event)
        #print(context)
        
        message = event['Records'][0]['Sns']['Message']
        
        messagejson = json.loads(message)


        Subject = event['Records'][0]['Sns']['Subject']
        print(Subject)
        
        if "TERMINATING" in Subject:
            instanceID= messagejson['EC2InstanceId']
            print(instanceID)
            print(f"TERMINATING instance: {instanceID}")
            #client = boto3.client('autoscaling')
            # response = client.complete_lifecycle_action(
            #     LifecycleHookName='asg-terminate-hook',
            #     AutoScalingGroupName='asg',
            #     LifecycleActionResult='ABANDON',
            #     InstanceId=instanceID
            # )

            # REMOVE WORKER FROM DYNAMODB
            response = table.query(KeyConditionExpression=Key('hostname').eq(instanceID))
            if response['Count'] > 0:
                # delete worker
                table.delete_item(Key={'hostname': instanceID},
                    ConditionExpression= 'attribute_exists(hostname)')

        if "LAUNCHING" in Subject:
            instanceID= messagejson['EC2InstanceId']
            print(instanceID)
            print(f"LAUNCHING instance: {instanceID}")
            client = boto3.client('autoscaling')
            response = client.complete_lifecycle_action(
                LifecycleHookName='asg-initialize-hook',
                AutoScalingGroupName='asg',
                LifecycleActionResult='CONTINUE',
                InstanceId=instanceID
            )

            for eip in getAvailableEIP():
                try:
                    print(f"...Associating EIP {eip}, to the EC2 instance {instanceID}")
                    # the disassocating of the EIP is made automatically when the ec2 instance is fully terminated
                    response = ec2.associate_address(InstanceId=instanceID, PublicIp=eip)
                    print(response)
                except ClientError as e:
                    print(e)
                break

            # ADD WORKER
            table.put_item(Item={
                'hostname': instanceID,
                'online': 'LAUNCHING'
            })


    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)





def getAvailableEIP():
    availableEIPs = []
    addresses_dict = ec2.describe_addresses()
    for eip_dict in addresses_dict['Addresses']:
        if "InstanceId" not in eip_dict:
            #print (eip_dict['PublicIp'] + " doesn't have any instances associated")
            availableEIPs.append(eip_dict['PublicIp'])     
        
    return availableEIPs


