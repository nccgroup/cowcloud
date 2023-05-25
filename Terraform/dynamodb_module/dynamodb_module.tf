variable "autoscaling_arn" {}
variable "maximum_number_of_terminating_machines" {}
variable "max_queued_tasks_per_worker" {}
variable "max_workers" {}
variable "retention_time" { }

resource "aws_dynamodb_table" "tasks_table" {
  name           = "tasks"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "taskID"
  stream_enabled   = true
  stream_view_type = "KEYS_ONLY"

  attribute {
    name = "taskID"
    type = "S"
  }
}
# taskID
# Domain
# S3Folder
# Status
# Worker

output "dynamodb_table_tasks_arn" {
  value = aws_dynamodb_table.tasks_table.arn
}

# ----

resource "aws_dynamodb_table" "archive_table" {
  name           = "archive"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "taskID"


  # DynamoDB does not delete expired items immediately. 
  # On Aws DynamoDB update-time-to-live command document, it states that expired items are removed within 2 days or 48 hours from expiration time. 
  # And, these supposedly expired items will stil show up in read, query and scan operations.
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }


  attribute {
    name = "taskID"
    type = "S"
  }
}
# taskID
# Domain
# S3Folder
# Status
# Worker

output "dynamodb_table_archive_arn" {
  value = aws_dynamodb_table.archive_table.arn
}

# ----

resource "aws_dynamodb_table" "workers_table" {
  name           = "workers"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "hostname"


  attribute {
    name = "hostname"
    type = "S"
  }
}
# HOSTNAME
# ONLINE


output "dynamodb_table_workers_arn" {
  value = aws_dynamodb_table.workers_table.arn
}

# ----

resource "aws_dynamodb_table" "scaling_settings" {
  name           = "scaling_settings"
  read_capacity  = 10
  write_capacity = 10
  hash_key       = "id"


  attribute {
    name = "id"
    type = "S"
  }
}


resource "aws_dynamodb_table_item" "add_initial_item" {
  table_name = aws_dynamodb_table.scaling_settings.name
  hash_key   = aws_dynamodb_table.scaling_settings.hash_key

  item = <<ITEM
{
  "id": {"S": "1"},
  "last_settings": {"S": "{\"totalNodes\": 10000, \"tasksMaxLimit\": 10000, \"taskMinLimit\": 10000, \"gracePoint\": 10000}"}
}
ITEM
}

# ---------------------------------------------------
# IAM

resource "aws_iam_role" "dynamodb_table_trigger_lambda_role" {
  name = "dynamodb_table_trigger_lambda_role"

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


resource "aws_iam_role_policy" "with_dynamodb" {
  name        = "with-dynamodb-for-event-source-mapping"
  role = aws_iam_role.dynamodb_table_trigger_lambda_role.id

  # "dynamodb:DescribeTable",
  # "dynamodb:ListTables",
  # "dynamodb:UpdateTable",

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:Scan",
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams",
        "dynamodb:ListShards"
      ],
      "Resource": [
        "${aws_dynamodb_table.tasks_table.arn}/stream/*",
        "${aws_dynamodb_table.tasks_table.arn}"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}


resource "aws_iam_role_policy" "with_dynamodb_two" {
  name        = "with_dynamodb_for-strategist"
  role = aws_iam_role.dynamodb_table_trigger_lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_dynamodb_table.scaling_settings.arn}"
        ]
      
    }
  ]
}
EOF

}



resource "aws_iam_role_policy" "with_watchlog" {
  name        = "dynamodb-tables-with-watchlog"
  role = aws_iam_role.dynamodb_table_trigger_lambda_role.id

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
        "${aws_cloudwatch_log_group.cloudwatch_log_dynamodb_table_lambda.arn}:log-stream:*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF

}


resource "aws_iam_role_policy" "with_autoscaling" {
  name        = "dynamodb-tables-with-autoscaling"
  role = aws_iam_role.dynamodb_table_trigger_lambda_role.id

#         "autoscaling:ExecutePolicy",
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:UpdateAutoScalingGroup"
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




# -----------
# LAMBDA

resource "aws_lambda_event_source_mapping" "map_events" {
  event_source_arn  = data.aws_dynamodb_table.tasks_table.stream_arn
  function_name     = aws_lambda_function.lambda.arn 
  starting_position = "LATEST"
}

data "aws_dynamodb_table" "tasks_table" {
  name = "tasks"
  depends_on = [aws_dynamodb_table.tasks_table]
}


resource "aws_cloudwatch_log_group" "cloudwatch_log_dynamodb_table_lambda" {
  name              = "/aws/lambda/${var.lambda_function_name_dynamodb_table_updates}"
  retention_in_days = var.retention_time
}

variable "lambda_function_name_dynamodb_table_updates" {
  default = "dynamodbTableUpdates"
}


data "archive_file" "dynamodbTableUpdates_zip" {
  type        = "zip"
  source_file = "${path.module}/${var.lambda_function_name_dynamodb_table_updates}.py"
  output_path = "${path.module}/outputs/${var.lambda_function_name_dynamodb_table_updates}.zip"
}

resource "aws_lambda_function" "lambda" {
  filename      = "${path.module}/outputs/${var.lambda_function_name_dynamodb_table_updates}.zip"
  function_name = var.lambda_function_name_dynamodb_table_updates
  role          = aws_iam_role.dynamodb_table_trigger_lambda_role.arn
  handler       = "${var.lambda_function_name_dynamodb_table_updates}.main"
  runtime       = "python3.7"

  source_code_hash = "${data.archive_file.dynamodbTableUpdates_zip.output_base64sha256}"

  environment {
    variables = {
      maximum_number_of_terminating_machines = "${var.maximum_number_of_terminating_machines}" 
      max_workers = "${var.max_workers}"
      max_queued_tasks_per_worker = "${var.max_queued_tasks_per_worker}"
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