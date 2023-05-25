resource "aws_sns_topic" "tasks" {
  name = "tasks-topic"
}

output "topic_task_arn" {
  value = aws_sns_topic.tasks.arn
}

resource "aws_sns_topic_subscription" "tasks_sqs_target" {
  topic_arn = aws_sns_topic.tasks.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.tasks_queue.arn
}

output "topic_arn" {
  value = aws_sns_topic_subscription.tasks_sqs_target.topic_arn

}

resource "aws_sqs_queue" "tasks_dl_queue" {
  name = "tasks-dl-queue"
  #fifo_queue                  = true
  #content_based_deduplication = true 
}

resource "aws_sqs_queue" "tasks_queue" {
  name = "tasks-queue"
  #fifo_queue                  = true
  #content_based_deduplication = true  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.tasks_dl_queue.arn
    maxReceiveCount     = 4
  })
}


resource "aws_sqs_queue_policy" "tasks_queue_policy" {
  queue_url = aws_sqs_queue.tasks_queue.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.tasks_queue.arn}"
    }
  ]
}
POLICY
}
# esto iba debajo de resource:
# "Resource": "${aws_sqs_queue.tasks_queue.arn}",
# "Condition": {
#         "ArnEquals": {
#           "aws:SourceArn": "${aws_sns_topic.example.arn}"
#         }
#       }


output "tasks_queue_arn" {
  value = aws_sqs_queue.tasks_queue.arn
  
}

output "tasks_queue_name" {
  value = aws_sqs_queue.tasks_queue.name
}