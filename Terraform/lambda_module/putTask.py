import json
import boto3
import os
import uuid
#import subprocess, sys
import traceback
from boto3.dynamodb.conditions import Key

def main(event, context):
    print("Hello from Lambda!")

    jsonbody = json.loads(event['body'])

    try:
        if jsonbody is not None and 'taskID' in jsonbody:
            taskID = jsonbody['taskID']
            task = interrupt_task(event, taskID)
        elif jsonbody is not None and 'message' in jsonbody:
            message = jsonbody['message']
            task = add_new_task(event, message)

        return {
            "headers": {
                "Access-Control-Allow-Origin": os.environ['schema_http']+"://"+os.environ['domain']
            },
            'statusCode': 200,
            'body': json.dumps(task)
        }
    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
        return {
            "headers": {
                "Access-Control-Allow-Origin": os.environ['schema_http']+"://"+os.environ['domain']
            },
            'statusCode': 500,
            'body': error_msg
        }


dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tasks') 
def interrupt_task(event, taskID):
    try:
        uid = event['requestContext']['authorizer']['claims']['sub']
        print(taskID)
        response = table.query(KeyConditionExpression=Key('taskID').eq(taskID))
        if response['Count'] > 0:
            _taskID = response['Items'][0]['taskID']
            _uid = response['Items'][0]['UID']
            if _taskID == taskID and _uid == uid:
                table.update_item(
                    Key={'taskID': taskID},
                    ConditionExpression= 'attribute_exists(taskID)',
                    UpdateExpression='SET StatusT = :val1',
                    ExpressionAttributeValues={
                        ':val1': 'INTERRUPT'
                    },
                )
            
    except Exception as e:
        raise Exception(e)
    
    return {'taskID':taskID}


def add_new_task(event, message):
    try:
        #raise Exception("AA")
        #message = event['queryStringParameters']['message']

        # message['UID'] = event['requestContext']['authorizer']['claims']['sub']
        # message = json.dumps(message)

        task = {}
        task['taskID'] = str(uuid.uuid4())
        task['passwd'] = str(uuid.uuid1())
        task['s3folder'] = str(uuid.uuid4())
        task['UID'] = event['requestContext']['authorizer']['claims']['sub']
        task['message'] = json.dumps(message)
        task['s3bucketURL']=f"https://{os.environ['s3bucket_name_results_storage']}.s3.amazonaws.com/{task['s3folder']}/compress_and_encrypted.tar.gz.enc"

        # CloudWatch
        logGroupName=f"/aws/ec2/ec2pyDockerLogs_{task['UID']}_{task['taskID']}"
        cWclient = boto3.client('logs')
        cWclient.create_log_group(
            logGroupName=logGroupName,
            tags={
                'name': 'dockerLogs'
            }
        )
        cWclient.put_retention_policy(
            logGroupName=logGroupName,
            retentionInDays=int(os.environ['retention_time'])
        )
        cWclient.create_log_stream(
            logGroupName=logGroupName,
            logStreamName='execution'
        )

        # DynamoDB

        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('tasks') 
        table.put_item(Item={
            'taskID': task['taskID'],
            'Message': task['message'],
            'S3Folder': task['s3folder'],
            'UID': task['UID'],
            'StatusT': 'IDLE',
            'Worker': 'None'
        })
        # Status: 1:IDLE, 2:RUNNING, 3:ERROR, 4:COMPLETED

        # S3 
        s3 = boto3.client('s3')
        s3.put_object(Bucket=os.environ['s3bucket_name_results_storage'], Key=(task['s3folder']+'/'))
        # , Tagging='Key=Report')
    

        # SNS
        message = task
        client = boto3.client('sns')
        response = client.publish(
            TargetArn=os.environ['topic_task_arn'],
            Message=json.dumps({'default': json.dumps(message)}),
            MessageStructure='json'
        )

    except Exception as e:
        raise Exception(e)

    return task


