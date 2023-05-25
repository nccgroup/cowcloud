import traceback
import logging
import boto3
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def main(event, context):
    try:
        client = boto3.client("logs")
        
        log_group_name = event['logGroupName']
        print("Delete log group:", log_group_name)

        client.delete_log_group(logGroupName=log_group_name)

        return {
            'statusCode': 200,
            'body': json.dumps('the countdown begins')
        }

    except Exception as e:
        tb_lines = [ line.rstrip('\n') for line in traceback.format_exception(e.__class__, e, e.__traceback__)]
        error_msg = str(tb_lines)
        print(error_msg)
