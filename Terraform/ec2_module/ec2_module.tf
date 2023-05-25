

variable "lambda_arn_workers_manager" { }
variable "myregion" { }
variable "accountId" { }
variable "tasks_queue_name" { }
variable "tasks_queue_arn" { }
variable "s3bucket_name_results_storage" { }
variable "s3bucket_arn_results_storage" { }
variable "s3bucket_name_ec2repository" {}
variable "s3bucket_arn_ec2repository" {}
variable "heartbeat_timeout" {}
variable "max_workers" {}
variable "maximum_number_of_terminating_machines" {}
variable "eipenable" {}
variable "ami" {}
variable "instance_type" {}
variable "cidr_whitelist" {}
variable "retention_time" { }
variable "dynamodb_table_tasks_arn" { }
variable "dynamodb_table_archive_arn" { }

resource "aws_eip" "cowCloud" {
    count = (var.eipenable) ? sum([var.max_workers, var.maximum_number_of_terminating_machines]) : 0

}

output "cowCloud_eips" {
  #description = "Elastic ip address for cowCloud workers"
  value       = aws_eip.cowCloud.*.public_ip
}

# 1. Create vpc
# 2. Create Internet gateway
# 3. Create Custom Route Table
# 4. Create a subnet
# 5. Associate subnet with Route Table
# 6. Create security group to allow port 22,80,443
# 7. Create a network interface with an ip in the subnet that was created in step 4
# 8. Assign an elastic IP to the network interface created in step 7
# 9. Create Ubuntu server and install/enable apache2
# ----------------------------------------------------------

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  default = [
    {cidr_block = "10.0.1.0/24", name = "prod_subnet"}
  ]
  #,     {cidr_block = "10.0.2.0/24", name = "dev_subnet"}
}

# 1. Create vpc
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    "Name" = "prod"
  }
}

# 2. Create Internet gateway
resource "aws_internet_gateway" "my-gw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    "Name" = "prod"
  }

}

# 3. Create Custom Route Table
resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    # Send traffic wherever this route points
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.my-gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. Create a subnet
resource "aws_subnet" "my-subnet" {
  vpc_id = aws_vpc.my-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    "Name" = var.subnet_prefix[0].name
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.my-route-table.id
}

# 6. Create security group to allow port 22,80,443
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  # ingress {
  #   description      = "HTTPS"
  #   from_port        = 443
  #   to_port          = 443
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  # }
  
  # ingress {
  #   description      = "HTTP"
  #   from_port        = 80
  #   to_port          = 80
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  # }
  
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.cidr_whitelist
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "prod_allows_web"
  }
}


# ------------------------------------------------------

resource "aws_cloudwatch_log_group" "ec2_instances_errors" {
  name              = "/aws/ec2/watchtower_workers_ec2instance_py"
  retention_in_days = var.retention_time

  tags = {
    Application = "workers_ec2instance.py"
  }
}

# resource "aws_cloudwatch_log_stream" "ec2_instances_errors" {
#   name           = "ec2_instances_errors"
#   log_group_name = aws_cloudwatch_log_group.ec2_instances_errors.name
# }

# --- IAM role

resource "aws_iam_role" "ec2_access_role" {
  name               = "ec2_access_role"

  # remove this line from the principal section when testing is finished "AWS":"arn:aws:iam::863994147283:user/Bob"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "with_dynamodb" {
  name = "ec2_instances_with_dynamodb"
  role = aws_iam_role.ec2_access_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": ["${var.dynamodb_table_tasks_arn}"],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:Attributes": [
            "StatusT",
            "taskID"
          ]
        },
        "StringEqualsIfExists": {"dynamodb:Select": "SPECIFIC_ATTRIBUTES"}
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "with_s3" {
  name = "ec2_instances_with_s3"
  role = aws_iam_role.ec2_access_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:PutObjectTagging"     
      ],
      "Effect": "Allow",
      "Resource": "${var.s3bucket_arn_results_storage}/*"
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${var.s3bucket_arn_ec2repository}",
        "${var.s3bucket_arn_ec2repository}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "with_invocation" {
  name = "ec2_instances_with_invocation"
  role = aws_iam_role.ec2_access_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": [
        "${var.lambda_arn_workers_manager}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "with_sns" {
  name = "ec2_instances_with_sns"
  role = aws_iam_role.ec2_access_role.id

#         "sns:Subscribe",
#         "sns:DeleteTopic"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${var.tasks_queue_arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "with_autoscaling" {
  name = "ec2_instances_with_autoscaling"
  role = aws_iam_role.ec2_access_role.id


  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:CompleteLifecycleAction"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "with_ec2" {
  name = "ec2_instances_with_ec2"
  role = aws_iam_role.ec2_access_role.id


  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeAddresses"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}



resource "aws_iam_role_policy" "with_cloudwatch" {
  name = "ec2_instances_with_cloudwatch"
  role = aws_iam_role.ec2_access_role.id

# quizá sean necesarios estos permisos, si no lo son eliminar estos mismos del role iam en lambda_module
#        "logs:CreateLogGroup",
#        "logs:CreateLogStream",
#"${aws_cloudwatch_log_group.docker_logs.arn}:log-stream:*",
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
        "${aws_cloudwatch_log_group.ec2_instances_errors.arn}:log-stream:*",
        "arn:aws:logs:${var.myregion}:${var.accountId}:log-group:/aws/ec2/ec2pyDockerLogs_*:log-stream:execution"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_instance_profile" "ec2_instances_profile" {
  name  = "ec2_instances_profile"
  role = aws_iam_role.ec2_access_role.name
}

# to debug locally
output "manager_ini" {
  value = {
    lambda_arn_workers_manager = "${var.lambda_arn_workers_manager}"
    tasks_queue_name = "${var.tasks_queue_name}"
    s3bucket_name_results_storage = "${var.s3bucket_name_results_storage}"
  }
}


resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "terraform-lc-example-"
  image_id      = "${var.ami}"
  instance_type = "${var.instance_type}"
  key_name = "cowCloud"
  security_groups = [aws_security_group.allow_ssh.id]
  # quiza esto en un futuro se pueda quitar, no hará falta acceder a las instancias.
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.ec2_instances_profile.name

  # This is to force metadata v2, which mitigates role credential leakage in the event of a SSRF
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }  

  user_data = <<-EOs
#!/bin/bash
yum update -y
mkdir /root/ec2app
aws s3 cp --recursive s3://${var.s3bucket_name_ec2repository}/ /root/ec2app

# IMDSv1: wget -q -O /root/ec2app/instance-id.txt http://169.254.169.254/latest/meta-data/instance-id
# IMDSv2: - you may need to install curl in the AMI before executing this:
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
curl -o /root/ec2app/instance-id.txt -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id

bash -c 'cat << EOF > /root/ec2app/manager.ini
[DEFAULT]
region = ${var.myregion}
lambda_arn_workers_manager = ${var.lambda_arn_workers_manager}
s3bucket_name_results_storage = ${var.s3bucket_name_results_storage}
EOF'

yum install -y nmap nano 
#yum install -y docker
# service docker start # UNCOMMENT THIS FOR THE AMI WITH RECONFTW

curl -s https://bootstrap.pypa.io/get-pip.py | python3 
pip3 install boto3 watchtower pyyaml pyAesCrypt requests
cd /root/ec2app/ && python3 main.py


# wget -O /root/stresscpu.sh https://raw.githubusercontent.com/elandsness/stresscpubash/master/stresscpu.sh
EOs

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 100
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# wget https://raw.githubusercontent.com/elandsness/stresscpubash/master/stresscpu.sh
# bash stresscpu.sh 2 300
# dd if=/dev/zero of=/dev/null

output "autoscaling_arn" {
  value = aws_autoscaling_group.bar.arn
}

resource "aws_autoscaling_group" "bar" {
  name                      = "asg"
  max_size                  = var.max_workers
  min_size                  = 0
  #health_check_grace_period = 300
  #health_check_type         = "ELB"
  desired_capacity          = 0
  #force_delete              = true
  #placement_group           = aws_placement_group.test.id
  launch_configuration      = aws_launch_configuration.as_conf.name
  vpc_zone_identifier       = [aws_subnet.my-subnet.id]

  # service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn


  enabled_metrics = [ 
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "foo"
    value               = "bar"
    propagate_at_launch = true
  }

  # timeouts {
  #   delete = "15m"
  # }

}


# resource "aws_autoscaling_policy" "scale_in" {
#   name                   = "scale_in"
#   scaling_adjustment     = 1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.bar.name
# }

# resource "aws_cloudwatch_metric_alarm" "cpu_alarm_up" {
#   alarm_name                = "cpu_alarm_up"
#   comparison_operator       = "GreaterThanOrEqualToThreshold"
#   evaluation_periods        = "2"
#   metric_name               = "CPUUtilization"
#   namespace                 = "AWS/EC2"
#   period                    = "120"
#   statistic                 = "Average"
#   threshold                 = "60"
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.bar.name
#   }
#   alarm_description = "This metric monitors ec2 cpu utilization"
#   alarm_actions     = [aws_autoscaling_policy.scale_in.arn]

# }

# resource "aws_autoscaling_policy" "scale_out" {
#   name                   = "scale_out"
#   scaling_adjustment     = -1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300 # The amount of time, in seconds, after a scaling activity completes and before the next scaling activity can start.
#   autoscaling_group_name = aws_autoscaling_group.bar.name
# }

# resource "aws_cloudwatch_metric_alarm" "cpu_alarm_down" {
#   alarm_name                = "cpu_alarm_down"
#   comparison_operator       = "LessThanOrEqualToThreshold"
#   evaluation_periods        = "2"
#   metric_name               = "CPUUtilization"
#   namespace                 = "AWS/EC2"
#   period                    = "120"
#   statistic                 = "Average"
#   threshold                 = "10"
#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.bar.name
#   }
#   alarm_description = "This metric monitors ec2 cpu utilization"
#   alarm_actions     = [aws_autoscaling_policy.scale_out.arn]

# }

# ---------------------------------------------


# aws autoscaling complete-lifecycle-action --lifecycle-hook-name foobar3-terraform-test-terminate-hook --auto-scaling-group-name foobar3-terraform-test --lifecycle-action-result ABANDON --instance-id ${INSTANCEID}  --region us-east-1

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "1"

    # REMOVE UNNECESSARY PERMISSIONS!, ADD RESOURCES TOO!
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:AssociateAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeHosts",
      "sns:Publish",
      "sns:ListSubscriptions",
      "dynamodb:DeleteItem",
      "dynamodb:PutItem",
      "dynamodb:Query"      
    ]

    resources = [
      "*",
    ]
  }
}

# 1. create IAM role assuming Lambda service
resource "aws_iam_role" "lambda" {
  assume_role_policy = <<EOF
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
EOF
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${aws_iam_role.lambda.name}-policy"
  role   = "${aws_iam_role.lambda.id}"
  policy = "${data.aws_iam_policy_document.lambda.json}"
}


# --------------------------------------

#       ,"sqs:SendMessage",
#      "sqs:GetQueueUrl",

data "aws_iam_policy_document" "auto_scaling_notification_access" {
  statement {
    sid = "1"

    actions = [
      "sns:Publish"
    ]

    resources = [
      "*",
    ]
  }
}

  
resource "aws_iam_role" "sns" {
  name = "${aws_autoscaling_group.bar.name}-notifies-sns"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "asg_notification_sns" {
  name   = "${aws_iam_role.sns.name}-asg-notification-policy"
  role   = "${aws_iam_role.sns.id}"
  policy = "${data.aws_iam_policy_document.auto_scaling_notification_access.json}"
}

#------------------------------

resource "aws_iam_role_policy" "asg_notification_lambda" {
  name   = "${aws_iam_role.lambda.name}-asg-notification-policy"
  role   = "${aws_iam_role.lambda.id}"
  policy = "${data.aws_iam_policy_document.auto_scaling_notification_access.json}"
}


# -------------------------------------


resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  function_name = "${aws_lambda_function.lambda.arn}"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.asg_sns.arn}"
}

resource "aws_sns_topic" "asg_sns" {
  name = "${aws_autoscaling_group.bar.name}-sns-topic"
}

resource "aws_sns_topic_subscription" "asg_sns" {
  topic_arn = "${aws_sns_topic.asg_sns.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.lambda.arn}"
}


# -------------------------

resource "aws_cloudwatch_log_group" "cloudwatch_log_workers_manager" {
  name              = "/aws/lambda/${var.lambda_function_name_lifecycleManager}"
  retention_in_days = var.retention_time
}

variable "lambda_function_name_lifecycleManager" {
  default = "lifecycleManager"
}


data "archive_file" "lifecycleManager_zip" {
  type        = "zip"
  source_file = "${path.module}/${var.lambda_function_name_lifecycleManager}.py"
  output_path = "${path.module}/outputs/${var.lambda_function_name_lifecycleManager}.zip"
}

resource "aws_lambda_function" "lambda" {
  filename      = "${path.module}/outputs/${var.lambda_function_name_lifecycleManager}.zip"
  function_name = var.lambda_function_name_lifecycleManager
  role          = aws_iam_role.lambda.arn
  handler       = "${var.lambda_function_name_lifecycleManager}.main"
  runtime       = "python3.7"

  source_code_hash = "${data.archive_file.lifecycleManager_zip.output_base64sha256}"

  # environment {
  #   variables = {
  #     cloudwatch_log_testing_name = "${aws_cloudwatch_log_group.cloudwatch_log_testing.name}" 
  #   }
  # }

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
      qualified_arn,
      version,
    ]
  }

}

# --------

resource "aws_autoscaling_lifecycle_hook" "terminate" {
  name                    = "${aws_autoscaling_group.bar.name}-terminate-hook"
  autoscaling_group_name  = "${aws_autoscaling_group.bar.name}"
  default_result          = "ABANDON"
  heartbeat_timeout       = "${var.heartbeat_timeout}" 
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = "${aws_sns_topic.asg_sns.arn}"
  role_arn                = "${aws_iam_role.sns.arn}"
}

resource "aws_autoscaling_lifecycle_hook" "initialize" {
  name                    = "${aws_autoscaling_group.bar.name}-initialize-hook"
  autoscaling_group_name  = "${aws_autoscaling_group.bar.name}"
  default_result          = "CONTINUE"
  heartbeat_timeout       = "2000"
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_LAUNCHING"
  notification_target_arn = "${aws_sns_topic.asg_sns.arn}"
  role_arn                = "${aws_iam_role.sns.arn}"
}