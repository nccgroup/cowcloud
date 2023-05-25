import json
import boto3
import os
import uuid
import traceback
import time

from decimal import Decimal

class DecimalEncoder(json.JSONEncoder):
    def default (self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return json.JSONEncoder.default(self, obj)

def view_task(event,data):
    UID= event['requestContext']['authorizer']['claims']['sub']

    cWclient = boto3.client('logs')
    timestamp = int(round(time.time() * 1000))
    task = event['queryStringParameters']['task']
    logGroupName=f'/aws/ec2/ec2pyDockerLogs_{UID}_{task}'
    
    data['logGroupName']=logGroupName
    
    query = "fields @timestamp, @message"  

    try:
        response = cWclient.get_log_events(
            logGroupName=logGroupName,
            logStreamName='execution'
        )
    except Exception as e:
        #raise e
        pass
    
    logMessage = ''
    latestTimestamp=''
    for event in response["events"]:
        logMessage=logMessage+event["message"]
        latestTimestamp=event["timestamp"]
    data['logMessage']= logMessage
    data['logLatestTimestamp'] = latestTimestamp
    
    return data


def view_all(data):
    try:
        dynamodb = boto3.resource('dynamodb')

        table = dynamodb.Table('tasks') 
        response = table.scan()
        data['tasks'] = response['Items']
    
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            data['tasks'].extend(response['Items'])
                
        
        table = dynamodb.Table('archive') 
        response = table.scan()
        data['archive'] = response['Items']
    
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            data['archive'].extend(response['Items'])
                
        
        table = dynamodb.Table('workers') 
        response = table.scan()
        data['workers'] = response['Items']
    
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            data['Workers'].extend(response['Items'])
    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
        
    return data

def main(event, context):
    print("Hello from Lambda! getObject")

    
    #type = event['queryStringParameters']['type']
    # DynamoDB

    data={}

    if event['queryStringParameters'] is not None and 'task' in event['queryStringParameters']:
        data = view_task(event,data)
    else:
        data = view_all(data)
        

    data= json.dumps(data, cls = DecimalEncoder)
    # scan = {}
    # scan["test"]= "testgetObject"
    return {
        "headers": {
            "Access-Control-Allow-Origin": os.environ['schema_http']+"://"+os.environ['domain']
        },
        'statusCode': 200,
        'body': data
    }