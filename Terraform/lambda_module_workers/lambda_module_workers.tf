
variable "dynamodb_table_tasks_arn" { }
variable "dynamodb_table_archive_arn" { }
variable "dynamodb_table_workers_arn" { }
variable "state_machine_arn" { }
variable "retention_time" { }

# IAM
resource "aws_iam_role" "workers_lambda_role" {
  name = "workers_lambda_role"

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

# ------

resource "aws_iam_policy" "with_dynamodb_workers_update" {
  name        = "with-dynamodb-permissions-workers-update"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "dynamodb:PutItem"
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.dynamodb_table_workers_arn}"
        ]
      
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy_workers_update" {
  role       = aws_iam_role.workers_lambda_role.name
  policy_arn = aws_iam_policy.with_dynamodb_workers_update.arn
}

# ------

resource "aws_iam_policy" "with_dynamodb_archive_put" {
  name        = "with-dynamodb-permissions-archive-put"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "dynamodb:PutItem"   
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.dynamodb_table_archive_arn}"
        ]
      
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy_archive_put" {
  role       = aws_iam_role.workers_lambda_role.name
  policy_arn = aws_iam_policy.with_dynamodb_archive_put.arn
}

# ------

resource "aws_iam_policy" "with_stepfunction_state_execution" {
  name        = "with-stepfunction-state-execution"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "states:StartExecution"
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.state_machine_arn}"
        ]
      
    }
  ]
}
EOF

}


resource "aws_iam_role_policy_attachment" "attach_stepfunction_policy" {
  role       = aws_iam_role.workers_lambda_role.name
  policy_arn = aws_iam_policy.with_stepfunction_state_execution.arn
}

# ------

resource "aws_iam_policy" "with_dynamodb_taks_update" {
  name        = "with-dynamodb-permissions-taks-update"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:GetItem",
            "dynamodb:Query"
        ],
        "Effect": "Allow",
        "Resource": [
          "${var.dynamodb_table_tasks_arn}"
        ]
      
    }
  ]
}
EOF

}


resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy_taks_update" {
  role       = aws_iam_role.workers_lambda_role.name
  policy_arn = aws_iam_policy.with_dynamodb_taks_update.arn
}


# ------

resource "aws_iam_role_policy" "with_watchlog_workers" {
  name        = "workers-lamda-with-watchlog"
  role = aws_iam_role.workers_lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.cloudwatch_log_workers_manager.arn}:log-stream:*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}

# ---------------------

resource "aws_cloudwatch_log_group" "cloudwatch_log_workers_manager" {
  name              = "/aws/lambda/${var.lambda_function_name_workers_manager}"
  retention_in_days = var.retention_time
}

# ------------------

variable "lambda_function_name_workers_manager" {
  default = "workers_manager"
}



# Lambda
resource "aws_lambda_permission" "workers_manager_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_arn_workers_manager.function_name
  principal     = "ec2.amazonaws.com"

  #source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${var.aws_api_gateway_rest_api_id}/*/${var.http_method_put_task}${var.aws_api_gateway_resource_path_put_task}"
}

data "archive_file" "workers_manager_zip" {
  type        = "zip"
  source_file = "${path.module}/${var.lambda_function_name_workers_manager}.py"
  output_path = "${path.module}/outputs/${var.lambda_function_name_workers_manager}.zip"
}

resource "aws_lambda_function" "lambda_arn_workers_manager" {
  filename      = "${path.module}/outputs/${var.lambda_function_name_workers_manager}.zip"
  function_name = var.lambda_function_name_workers_manager
  role          = aws_iam_role.workers_lambda_role.arn
  handler       = "${var.lambda_function_name_workers_manager}.main"
  runtime       = "python3.7"

  source_code_hash = "${data.archive_file.workers_manager_zip.output_base64sha256}"

  environment {
    variables = {
      retention_time = "${var.retention_time}",
      state_machine_arn = "${var.state_machine_arn}" 
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

output "lambda_arn_workers_manager" {
    value = "${aws_lambda_function.lambda_arn_workers_manager.arn}"
  
}
