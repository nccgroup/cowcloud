# import json
import boto3
from boto3.dynamodb.conditions import Key
import os
# import uuid
# import logging
import traceback
import datetime 
import time
import json
import os

dynamodb = boto3.resource('dynamodb')
sfn_client = boto3.client('stepfunctions')
reponse = {}


def start_cloudwatchgroups_countdown(UID, taskID):
    try:
        state_machine_arn = os.environ['state_machine_arn']
        response = sfn_client.start_execution(
            stateMachineArn=state_machine_arn,
            name=f"{UID}_{taskID}",
            input=json.dumps({"lambda": {"logGroupName": f"/aws/ec2/ec2pyDockerLogs_{UID}_{taskID}"}})
        )
        print(response)
    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
 


def workers(event):
    table = dynamodb.Table('workers') 
    error_msg = None
    try:
        table.put_item(Item={
            'hostname': event['hostname'],
            'online': event['online']
        })
    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
        return 501, error_msg

    return 200, error_msg

def tasks(event):
    print(event)
    table = dynamodb.Table('tasks') 
    StatusT = event['StatusT']
    taskID = event['taskID']
    UID = event['UID'] if 'UID' in event else None
    error_msg = None

    # the cloudwatch log groups that holds the ec2py/template.py output will be deleted after the retention_time expires
    if UID and StatusT == "RUNNING":
        start_cloudwatchgroups_countdown(UID, taskID)
    elif StatusT == "RUNNING" and UID is None :
        return 501, "UID is missing"


    try:
        if StatusT == "COMPLETED" or "ERROR" in StatusT:
            # fetch task
            response = table.query(KeyConditionExpression=Key('taskID').eq(taskID))
            if response['Count'] > 0:
                # delete task
                table.delete_item(Key={'taskID': taskID},
                    ConditionExpression= 'attribute_exists(taskID)')

                table = dynamodb.Table('archive') 
                week = datetime.datetime.today() + datetime.timedelta(days=int(os.environ['retention_time']))
                expiryDateTime = int(time.mktime(week.timetuple())) 
                
                if response['Items'][0]['StatusT'] == 'INTERRUPT':
                    StatusT = 'INTERRUPT'
                # put task in archive table
                table.put_item(Item={
                    'Worker': response['Items'][0]['Worker'],
                    'Message': response['Items'][0]['Message'],
                    'S3Folder': response['Items'][0]['S3Folder'],
                    'UID': response['Items'][0]['UID'],
                    'StatusT': StatusT,
                    'taskID': response['Items'][0]['taskID'],
                    'ttl': expiryDateTime
                })
        else:
            response = table.query(KeyConditionExpression=Key('taskID').eq(taskID))
            if response['Count'] > 0:
                if response['Items'][0]['StatusT'] != 'INTERRUPT':
                    worker = event['Worker']
                    table.update_item(
                        Key={'taskID': event['taskID']},
                        ConditionExpression= 'attribute_exists(taskID)',
                        UpdateExpression='SET StatusT = :val1, Worker = :val2',
                        ExpressionAttributeValues={
                            ':val1': StatusT,
                            ':val2': worker
                        },
                    )

    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
        return 501, error_msg

    return 200, error_msg

# def archive(event):
#     table = dynamodb.Table('archive') 
#     try:
#         table.put_item(Item={
#             'taskID': event['taskID'],
#             'Message': event['Message'],
#             'S3Folder': event['S3Folder'],
#             'StatusT': event['StatusT'],
#             'Worker': event['Worker']
#         })
#     except Exception as e:
#         error.append(str(e))
#         return 500
#     return 200

def main(event, context):
    print("Hello from Lambda! getObject")


    response = {}
    if event['type'] == 'worker':
        statuscode, error_msg = workers(event)
        response['Error message'] = error_msg
        response['Execution code'] = statuscode
    elif event['type'] == 'tasks':
        statuscode, error_msg = tasks(event)
        response['Error message'] = error_msg
        response['Execution code'] = statuscode
    else:
        response['Execution code'] = 500
        response['Error message'] = "no type selected"

    #response['Error message'] = error
    # To debug, change response for error
    return response