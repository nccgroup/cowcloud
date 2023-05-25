variable "aws_api_gateway_rest_api_id" { }

#variable "aws_api_gateway_method_http_method" { }
variable "aws_api_gateway_resource_path_put_task" { }
variable "aws_api_gateway_resource_path_get_object" { }
variable "http_method_put_task" { }
variable "http_method_get_object" { }

variable "topic_task_arn" {}
variable "tasks_queue_arn" { }
variable "accountId" { }
variable "myregion" { }
variable "s3bucket_arn_results_storage" { }
variable "s3bucket_name_results_storage" { }
variable "dynamodb_table_tasks_arn" { }
variable "dynamodb_table_archive_arn" { }
variable "dynamodb_table_workers_arn" { }
variable "domain" { }
variable "schema_http" { }
variable "retention_time" { }



# $funcName = "putTask"
# $test=aws logs describe-log-streams --log-group-name "/aws/lambda/$funcName" --query "logStreams[*].logStreamName | [-1]"
# aws logs get-log-events --log-group-name "/aws/lambda/$funcName" --log-stream-name $test --query "events[*].message"


# -----------------------------
# IAM Role

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "with_dynamodb" {
  name        = "with-dynamodb-permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem"  
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.dynamodb_table_tasks_arn}",
          "${var.dynamodb_table_archive_arn}",
          "${var.dynamodb_table_workers_arn}"
        ]
      
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.with_dynamodb.arn
}

# -------

resource "aws_iam_policy" "with_s3" {
  name        = "with-s3-permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "s3:PutObject",
            "s3:PutObjectAcl"
             
        ],
        "Effect": "Allow",
        "Resource": "${var.s3bucket_arn_results_storage}/*"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.with_s3.arn
}

# -------


resource "aws_iam_policy" "with_cloudWatch" {
  name        = "with-cloudWatch-permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "logs:DescribeLogStreams",
            "logs:GetLogEvents",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutRetentionPolicy"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:logs:${var.myregion}:${var.accountId}:log-group:/aws/ec2/ec2pyDockerLogs_*:log-stream:*"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_cloudWatch_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.with_cloudWatch.arn
}


# -------

resource "aws_iam_policy" "with_sns" {
  name        = "with-sns-permissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "sns:Publish",
            "sns:Subscribe"        
        ],
        "Effect": "Allow",
        "Resource": "${var.topic_task_arn}"
      
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_sns_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.with_sns.arn
}

# -------

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

# Specify the resource arn
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.cloudwatch_log_group_put_object.arn}:log-stream:*",
        "${aws_cloudwatch_log_group.cloudwatch_log_group_get_object.arn}:log-stream:*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}
#        "logs:CreateLogGroup",
#"Resource": "arn:aws:logs:*:*:*",

resource "aws_iam_role_policy_attachment" "attach_lambda_logs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}


# -----------------------------
# CloudWatch

resource "aws_cloudwatch_log_group" "cloudwatch_log_group_put_object" {
  name              = "/aws/lambda/${var.lambda_function_name_put_object}"
  retention_in_days = var.retention_time
}


resource "aws_cloudwatch_log_group" "cloudwatch_log_group_get_object" {
  name              = "/aws/lambda/${var.lambda_function_name_get_object}"
  retention_in_days = var.retention_time
}


# --------------------------------------------------------------
# POST method


variable "lambda_function_name_put_object" {
  default = "putTask"
}



# Lambda
resource "aws_lambda_permission" "apigw_lambda_put_object" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_put_object.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${var.aws_api_gateway_rest_api_id}/*/${var.http_method_put_task}${var.aws_api_gateway_resource_path_put_task}"
}

data "archive_file" "putTask_zip" {
  type        = "zip"
  source_file = "${path.module}/putTask.py"
  output_path = "${path.module}/outputs/putTask.zip"
}

resource "aws_lambda_function" "lambda_put_object" {
  filename      = "${path.module}/outputs/putTask.zip"
  function_name = var.lambda_function_name_put_object
  role          = aws_iam_role.lambda_role.arn
  handler       = "putTask.main"
  runtime       = "python3.7"
  timeout       = 6
  memory_size   = 256

  source_code_hash = "${data.archive_file.putTask_zip.output_base64sha256}"

  environment {
    variables = {
      topic_task_arn = "${var.topic_task_arn}"
      s3bucket_name_results_storage = "${var.s3bucket_name_results_storage}"
      schema_http = "${var.schema_http}"
      domain = "${var.domain}"
      cloudwatch_log_group_put_object_name = "${aws_cloudwatch_log_group.cloudwatch_log_group_put_object.name}" 
      retention_time = "${var.retention_time}"

    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
      qualified_arn,
      version,
    ]
  }

}

output "lambda_arn" {
    value = "${aws_lambda_function.lambda_put_object.invoke_arn}"
  
}


# --------------------------------------------------------------
# GET method

variable "lambda_function_name_get_object" {
  default = "getObject"
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda_get_object" {
  statement_id  = "AllowExecutionFromAPIGateway-getObject"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_get_object.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${var.aws_api_gateway_rest_api_id}/*/${var.http_method_get_object}${var.aws_api_gateway_resource_path_get_object}"
}

data "archive_file" "getObject_zip" {
  type        = "zip"
  source_file = "${path.module}/getObject.py"
  output_path = "${path.module}/outputs/getObject.zip"
}

resource "aws_lambda_function" "lambda_get_object" {
  filename      = "${path.module}/outputs/getObject.zip"
  function_name = var.lambda_function_name_get_object
  role          = aws_iam_role.lambda_role.arn
  handler       = "getObject.main"
  runtime       = "python3.7"

  source_code_hash = "${data.archive_file.getObject_zip.output_base64sha256}"

  environment {
    variables = {
      schema_http = "${var.schema_http}"
      domain = "${var.domain}"
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
      qualified_arn,
      version,
    ]
  }

}


output "lambda_arn_get_object" {
    value = "${aws_lambda_function.lambda_get_object.invoke_arn}"
  
}



