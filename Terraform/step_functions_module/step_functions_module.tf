variable "retention_time" { }

variable "stepfunction_and_lambda_function_name_cloudwatch_group_deletion" {
    default = "cloudWatchGroupDeletions"
}


# STEP FUNCTION

resource "aws_cloudwatch_log_group" "cloudwatch_group_deletion_log_group_step_function" {
  name              = "/aws/stepfunction/states/${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}"
  retention_in_days = var.retention_time
}

# Call stf with this payload
# {
#      "lambda": {
#     "logGroupName": "/aws/ec2/ec2pyDockerLogs_0f126412-9350-4b71-a7d5-251bebf6d9ff_082d5ea8-0bb2-4c88-9bb4-bab91944dd1d"
#   }
# }
# {
#      "lambda": {
#     "logGroupName": "/aws/ec2/ec2pyDockerLogs_0f126412-9350-4b71-a7d5-251bebf6d9ff_1eb7ee45-3130-4e2e-9bfc-bffac740eaa7"
#   }
# }

resource "aws_sfn_state_machine" "sfn_state_machine_for_cloudwatch_group_deletion_after_delay" {
  name     = "${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}"
  role_arn = aws_iam_role.stepfunction_role_for_cloudwatch_group_deletion.arn

  # 86400 seconds in a day
  definition = <<EOF
{
  "Comment": "Call Lambda function after X seconds",
  "StartAt": "wait_seconds",
  "States": {
     "wait_seconds": {
      "Type": "Wait",
      "Seconds": ${86400 * var.retention_time},
      "Next": "execute_lambda_function"
    },
    "execute_lambda_function": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.cloudwatch_group_deletion_lambda.arn}",
      "InputPath": "$.lambda",
      "End": true
    }
  }
}
EOF

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.cloudwatch_group_deletion_log_group_step_function.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

}
  
output "state_machine_arn" {
  value = "${aws_sfn_state_machine.sfn_state_machine_for_cloudwatch_group_deletion_after_delay.arn}"
}



# ------------------------------

# LAMBDA
resource "aws_cloudwatch_log_group" "cloudwatch_group_deletion_log_group" {
  name              = "/aws/lambda/${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}"
  retention_in_days = var.retention_time
}


data "archive_file" "cloudWatchGroupDeletions_zip" {
  type        = "zip"
  source_file = "${path.module}/${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}.py"
  output_path = "${path.module}/outputs/${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}.zip"
}

resource "aws_lambda_function" "cloudwatch_group_deletion_lambda" {
  filename      = "${path.module}/outputs/${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}.zip"
  function_name = "${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}"
  role          = aws_iam_role.lambda_role_for_cloudwatch_group_deletion.arn
  handler       = "${var.stepfunction_and_lambda_function_name_cloudwatch_group_deletion}.main"
  runtime       = "python3.7"

  source_code_hash = "${data.archive_file.cloudWatchGroupDeletions_zip.output_base64sha256}"

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
      qualified_arn,
      version,
    ]
  }

}



# ---------------------------------------------------
# IAM for Lambda function


resource "aws_iam_role" "lambda_role_for_cloudwatch_group_deletion" {
  name = "lambda_role_for_cloudwatch_group_deletion"

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


resource "aws_iam_role_policy" "lf_with_cloudwatch_deletion" {
  name        = "lf_with_cloudwatch_deletion"
  role = aws_iam_role.lambda_role_for_cloudwatch_group_deletion.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:DeleteLogGroup",
                "logs:DeleteLogStream"
            ],
            "Resource": "*"
        }
    ]
}
EOF

}

resource "aws_iam_role_policy" "lf_with_cloudwatch" {
  name        = "lf_with_cloudwatch"
  role = aws_iam_role.lambda_role_for_cloudwatch_group_deletion.id

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
        "${aws_cloudwatch_log_group.cloudwatch_group_deletion_log_group.arn}:log-stream:*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}

# --------------------
## IAM for Step Function

resource "aws_iam_role" "stepfunction_role_for_cloudwatch_group_deletion" {
  name = "stepfunction_role_for_cloudwatch_group_deletion"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}


resource "aws_iam_role_policy" "stf_with_lambda_invocation" {
  name        = "stf_with_lambda_invocation"
  role = aws_iam_role.stepfunction_role_for_cloudwatch_group_deletion.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "${aws_lambda_function.cloudwatch_group_deletion_lambda.arn}:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "${aws_lambda_function.cloudwatch_group_deletion_lambda.arn}"
            ]
        }
    ]
}
EOF

}

resource "aws_iam_role_policy" "stf_with_cloudwatch" {
  name        = "stf_with_cloudwatch"
  role = aws_iam_role.stepfunction_role_for_cloudwatch_group_deletion.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        "logs:DescribeLogGroups"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}