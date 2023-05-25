## Common errors

You may run into this error while destroying your infrastructure. Read below to understand the reason.
`Error: error waiting for Step Function State Machine (arn:aws:states:us-east-1:199346970110:stateMachine:cloudWatchGroupDeletions) deletion: timeout while waiting for resource to be gone (last state: 'DELETING', timeout: 5m0s)`

When a new task is pulled by a worker, the worker starts executing the task and starts a countdown so that the CloudWatch log group that the worker uses to log the stdout of that execution is removed in due time. This time is determined by the `retention_time` variable. On the other hand, the countdown is handled by a step function that once executed sits idle so that the stdout is visible through the web interface until the timeout has passed. This behaviour allows the stdout to be stored for some time, but also prevents the State Machine from being deleted during that time.

#### Solution:
You'll have to log into the console, and stop the Step Function State Machine executions, then you will be able to destroy the Step Function, run again `terraform destroy`. This will solve this issue, however the step function won't be able delete the CloudWatch log groups, so it's advised, that you also delete the log group manually. You just need to remove those log groups starting with `/aws/ec2/ec2pyDockerLogs_`

#### Note:
Although the CloudWatch log retention deletes the log events in the stream of those log groups for the stdout, the log groups remain undeleted, that's why I came up with this solution of using a Step Function, so that the log groups will also be removed.

---
You may run into this error while creating the infrastructure:

`Error: Cannot fetch root device name for blank AMI ID`

#### Solution:
Set a valid AMI into the `ami` variable `terraform/variables.tf`

---

### Following the list of permission for the role attached to the EC2 instances profile:


```json
{
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
	},
	{
		"Action": [
			"logs:PutLogEvents",
			"logs:CreateLogStream"
		],
		"Resource": [
			"arn:aws:logs:us-east-1:199346970110:log-group:/aws/ec2/watchtower_workers_ec2instance_py:log-stream:*",
			"arn:aws:logs:us-east-1:199346970110:log-group:/aws/ec2/ec2pyDockerLogs_*:log-stream:execution"
		],
		"Effect": "Allow"
	},
	{
		"Effect": "Allow",
		"Action": [
			"dynamodb:GetItem",
			"dynamodb:Query",
			"dynamodb:Scan"
		],
		"Resource": [
			"arn:aws:dynamodb:us-east-1:199346970110:table/tasks"
		],
		"Condition": {
			# The following permissions policy allows access to only two specific attributes in a table by adding the dynamodb:Attributes condition key
			"ForAllValues:StringEquals": {
				"dynamodb:Attributes": [
					"StatusT",
					"taskID"
				]
			},
			"StringEqualsIfExists": {
				"dynamodb:Select": "SPECIFIC_ATTRIBUTES"
			}
		}
	},
	{
		"Action": [
			"ec2:DescribeAddresses"
		],
		"Effect": "Allow",
		"Resource": [
			"*"
		]
	},
	{
		"Action": "lambda:InvokeFunction",
		"Effect": "Allow",
		"Resource": [
			"arn:aws:lambda:us-east-1:199346970110:function:workers_manager"
		]
	},
	{
		"Action": [
			"s3:PutObject",
			"s3:PutObjectAcl",
			"s3:PutObjectTagging"
		],
		"Effect": "Allow",
		"Resource": "arn:aws:s3:::scans-storage-5m2jrl9t-cowcloud/*"
	},
	{
		"Action": [
			"s3:GetObject",
			"s3:ListBucket"
		],
		"Effect": "Allow",
		"Resource": [
			"arn:aws:s3:::ec2py-repo-5m2jrl9t-cowcloud",
			"arn:aws:s3:::ec2py-repo-5m2jrl9t-cowcloud/*"
		]
	},
	{
		"Action": [
			"sqs:ReceiveMessage",
			"sqs:DeleteMessage",
			"sqs:GetQueueAttributes",
			"sqs:GetQueueUrl"
		],
		"Effect": "Allow",
		"Resource": [
			"arn:aws:sqs:us-east-1:199346970110:tasks-queue"
		]
	}		
]
}
```

### Next, the list of permission attached the role used by the lambda function `workers_manager.py`

```json
{
"Statement": [
    {
        "Action": [
            "dynamodb:PutItem"
        ],
        "Effect": "Allow",
        "Resource": [
            "arn:aws:dynamodb:us-east-1:199346970110:table/archive"
        ]
    },
    {
        "Action": [
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:GetItem",
            "dynamodb:Query"
        ],
        "Effect": "Allow",
        "Resource": [
            "arn:aws:dynamodb:us-east-1:199346970110:table/tasks"
        ]
    },
    {
        "Action": [
            "dynamodb:PutItem"
        ],
        "Effect": "Allow",
        "Resource": [
            "arn:aws:dynamodb:us-east-1:199346970110:table/workers"
        ]
    },
    {
        "Action": [
            "logs:PutLogEvents",
            "logs:CreateLogStream"
        ],
        "Resource": [
            "arn:aws:logs:us-east-1:199346970110:log-group:/aws/lambda/workers_manager:log-stream:*"
        ],
        "Effect": "Allow"
    }
]
}
```