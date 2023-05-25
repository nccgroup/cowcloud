import json
import boto3
import os
import uuid
import traceback
import math
import boto3
from boto3.dynamodb.conditions import Key

maximum_number_of_terminating_machines = os.environ['maximum_number_of_terminating_machines']
max_workers = int(os.environ['max_workers']) 
max_queued_tasks_per_worker = int(os.environ['max_queued_tasks_per_worker']) 

dynamodb = boto3.resource('dynamodb')
table_scaling_settings = dynamodb.Table('scaling_settings') 
table_tasks = dynamodb.Table('tasks') 
autoscalingClient = boto3.client('autoscaling')

debug = False
settings = []


# Grace point definition: a grace point is assigned to each limit, this bit prevents scaling out due to decrasing a single task.  
#                   {"totalNodes": 2, "tasksMaxLimit": [20], "taskMinLimit": 10},
# given this limit: {"totalNodes": 3, "tasksMaxLimit":  30,  "taskMinLimit": 20}, the grace point is 15
# the grace point is calculated based on tasksMaxLimit of the previous limit. 
# totalTasks = 19 means 2 node
# totalTasks = 20 means 3 node
# totalTasks = 19 still means 3 node; the three nodes will remain until reached the grace point (15)
#
# Test:
# Total task: 20, TotalNodes: 3
# Total task: 15, TotalNodes: 3
# Total task: 14, TotalNodes: 2
# Total task: 1, TotalNodes: 1
# Total task: 10, TotalNodes: 2
# Total task: 5, TotalNodes: 2
# Total task: 4, TotalNodes: 1


class autoscalingStrategist():

    def __init__(self, settings):
        self.settings=self.create_settings()
        self.lastSettings=json.loads(self.query_last_settings())
        self.task_limit_to_scale_in = self.settings[len(self.settings)-1]["tasksMaxLimit"]

    def get_settings(self):
        return self.settings

    def create_settings(self):
        taskMinLimit = 0
        tasksMaxLimit = max_queued_tasks_per_worker
        _settings = []
        for x in range(1, max_workers+1):
            _w = {}
            _w["totalNodes"] = x
            _w["tasksMaxLimit"] = tasksMaxLimit
            _w["taskMinLimit"] = taskMinLimit
            _settings.append(_w)
            taskMinLimit = taskMinLimit + max_queued_tasks_per_worker
            tasksMaxLimit = tasksMaxLimit + max_queued_tasks_per_worker

        # Configure grace point, in other words the number of tasks before scale out to a lower level
        for i in range(len(_settings)):
            if i >0:
                _settings[i]['gracePoint'] = math.floor( ( _settings[i-1]['taskMinLimit'] + _settings[i-1]['tasksMaxLimit'] ) / 2)
        return _settings

    def check(self, num_tasks):
        if num_tasks == 0:
            return 0

        nodes=0
        if num_tasks >= self.task_limit_to_scale_in:
            index=len(self.settings)-1
            self.lastSettings=self.settings[index]
            return self.settings[index]['totalNodes']


        if 'gracePoint' in self.lastSettings and num_tasks >= self.lastSettings['gracePoint'] and num_tasks < self.lastSettings['tasksMaxLimit']:
            nodes=self.lastSettings['totalNodes']
            return nodes
            
        for limit in self.settings:
            if num_tasks >= limit['taskMinLimit'] and num_tasks < limit['tasksMaxLimit']:
                nodes = limit['totalNodes']
                self.lastSettings=limit
                self.update_last_settings(limit)
                return nodes

    def query_tasks(self):
        response = table_tasks.scan()
        data = response['Items']

        while 'LastEvaluatedKey' in response:
            response = table_tasks.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            data.extend(response['Items'])

        countActiveTasks = len(data)
        return countActiveTasks

    def query_last_settings(self):
        response = table_scaling_settings.query(KeyConditionExpression=Key('id').eq("1"))
        return response['Items'][0]['last_settings']

    def update_last_settings(self, last_settings):
        table = dynamodb.Table('scaling_settings') 
        table.update_item(
            Key={'id': "1"},
            ConditionExpression= 'attribute_exists(id)',
            UpdateExpression='SET last_settings = :val1',
            ExpressionAttributeValues={
                ':val1': json.dumps(last_settings)
            },
        )


    def query_active_ec2instances(self):
        response = autoscalingClient.describe_auto_scaling_groups()
        desire_capacity = response["AutoScalingGroups"][0]["DesiredCapacity"]
        if debug:
            print(f"desire_capacity: {desire_capacity}")
        actives_or_about_to_become_active = 0
        terminated_or_about_to_terminate = 0
        for i in response["AutoScalingGroups"][0]["Instances"]:
            if debug:
                print(i["LifecycleState"])
            if "Pending" in i["LifecycleState"] or i["LifecycleState"] == "InService":
                actives_or_about_to_become_active = actives_or_about_to_become_active + 1
            else:
                terminated_or_about_to_terminate = terminated_or_about_to_terminate + 1

        return str(actives_or_about_to_become_active), str(terminated_or_about_to_terminate), desire_capacity

    def configure_autoscaling_group(self, terminated_or_about_to_terminate, desire_capacity, nodes_to_scale):
        # it can scale in or out as long as the max number of terminating machines hasn't been reached.
        if terminated_or_about_to_terminate <= maximum_number_of_terminating_machines :   
            if nodes_to_scale == desire_capacity:
                print("nothing to change, the desire capacity and the number of nodes that should exist match (based on the count of tasks)")           
            else:
                print(f"New desired capacity: {nodes_to_scale}")
                response = autoscalingClient.update_auto_scaling_group(
                    AutoScalingGroupName='asg',
                    DesiredCapacity=nodes_to_scale
                ) 

            
        else:
            # if the max number of terminating machines has been reached, it can only scale out.
            print("maximum number of terminating workers has been reached, no scaling is going to happen until those workers timeout or the tools running on them finishes")
            if nodes_to_scale < desire_capacity:
                print(f"New desired capacity: {nodes_to_scale}. Decreasing")
                response = autoscalingClient.update_auto_scaling_group(
                    AutoScalingGroupName='asg',
                    DesiredCapacity=nodes_to_scale
                )
            elif nodes_to_scale == desire_capacity:
                print("nothing to change, the desire capacity and the number of nodes that should exist match (based on the count of tasks)")

        


def main(event, context):
    try:
        x = autoscalingStrategist(settings)
        print(json.dumps(x.get_settings(), indent=4, sort_keys=True))
        totalNumberOfTasks = x.query_tasks()
        nodes_to_scale = x.check(totalNumberOfTasks)

        print(f"Total task: {totalNumberOfTasks}, TotalNodes: {nodes_to_scale}")
        actives_or_about_to_become_active, terminated_or_about_to_terminate, desire_capacity = x.query_active_ec2instances()
        print(f"actives Or About To Become Active: {actives_or_about_to_become_active}, terminated Or About To Terminate: {terminated_or_about_to_terminate}, desire capacity: {desire_capacity}")
        x.configure_autoscaling_group(terminated_or_about_to_terminate, desire_capacity, nodes_to_scale)


    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
