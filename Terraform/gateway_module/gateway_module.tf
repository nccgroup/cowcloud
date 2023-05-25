
variable "lambda_arn" { }
variable "lambda_arn_get_object" { }
variable "myregion" { }
variable "accountId" { }
variable "domain" { }
variable "schema_http" { }
variable "retention_time" { }
variable "cidr_whitelist" { }
variable "cognito_user_pool_name" { }
variable "cognito_pool_depends_on" {
  # the value doesn't matter; we're just using this variable
  # to propagate dependencies.
  type    = any
  default = []
}

resource "aws_iam_role" "invocation_role" {
  name = "api_gateway_auth_invocation"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.invocation_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": [
        "${var.lambda_arn}",
        "${var.lambda_arn_get_object}"
      ]
    }
  ]
}
EOF
}


# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "scanner"
}

resource "aws_api_gateway_rest_api_policy" "apipolicy" {
  count = (length(var.cidr_whitelist) > 0) ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.api.id

  # Any change in the Api gateway resource policy requires a redeployment of the same stage,
  # go to Resources, Actions, Deploy API
  # AFTER REDEPLOY YOU NEED TO WAIT A FEW MINUTES FOR THE CHAGES TO PROPAGATE
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
          "Effect": "Allow",
          "Principal": "*",
          "Action": "execute-api:Invoke",
          "Resource": "${aws_api_gateway_rest_api.api.execution_arn}/*"
      },
      {
          "Effect": "Deny",
          "Principal": "*",
          "Action": "execute-api:Invoke",
          "Resource": "${aws_api_gateway_rest_api.api.execution_arn}/*",
          "Condition": {
              "NotIpAddress": {
                  "aws:SourceIp": var.cidr_whitelist
              }
          }
      }
    ]
  })
}

output "aws_api_gateway_rest_api_id" {
  value = aws_api_gateway_rest_api.api.id
}


data "aws_api_gateway_rest_api" "selected" {
    name = "${aws_api_gateway_rest_api.api.name}"
}

data "aws_cognito_user_pools" "selected" {
  name = var.cognito_user_pool_name
  depends_on = [var.cognito_pool_depends_on]
}

# --------------------------------------------------------------
# POST method


resource "aws_api_gateway_authorizer" "gateway_authorizer_put_task" {
  name                   = "gateway_authorizer_put_task"
  rest_api_id            = data.aws_api_gateway_rest_api.selected.id
  authorizer_uri         = var.lambda_arn
  authorizer_credentials = aws_iam_role.invocation_role.arn

  type = "COGNITO_USER_POOLS"
  provider_arns = "${data.aws_cognito_user_pools.selected.arns}"

  # probar a comentar esta linea:
  depends_on = [var.cognito_pool_depends_on]

}


resource "aws_api_gateway_resource" "resource_put_task" {
  path_part   = "putTask"
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api.id
}

output "aws_api_gateway_resource_path_put_task" {
  value = aws_api_gateway_resource.resource_put_task.path

}

# ----- REQUEST

locals {
  http_method_put_task = "PUT"
}

output "http_method_put_task" {
  value = local.http_method_put_task
}

resource "aws_api_gateway_method" "method_request_put_task" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource_put_task.id
  http_method   = local.http_method_put_task
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.gateway_authorizer_put_task.id
  authorization_scopes = ["email"]

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# output "aws_api_gateway_method_http_method" {
#   value = aws_api_gateway_method.method.http_method

# }

resource "aws_api_gateway_integration" "integration_request_put_task" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource_put_task.id
  http_method             = aws_api_gateway_method.method_request_put_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn
}

# ----- RESPONSE

resource "aws_api_gateway_method_response" "method_response_put_task" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_put_task.id}"
  http_method = "${aws_api_gateway_method.method_request_put_task.http_method}"
  status_code = "200"
  # response_models = {
  #   "application/json" = "Empty"
  # }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.cors_put_task]
}


# --------------------------------------------------------------
# GET method

# https://aws.amazon.com/premiumsupport/knowledge-center/api-gateway-403-error-lambda-authorizer/
# ... getObjects with an explicit deny
# ... getObjects

resource "aws_api_gateway_authorizer" "gateway_authorizer_get_object" {
  name                   = "gateway-authorizer-get-object"
  rest_api_id            = data.aws_api_gateway_rest_api.selected.id
  authorizer_uri         = var.lambda_arn_get_object
  authorizer_credentials = aws_iam_role.invocation_role.arn

  type = "COGNITO_USER_POOLS"
  provider_arns = "${data.aws_cognito_user_pools.selected.arns}"

  # probar a comentar esta linea:
  depends_on = [var.cognito_pool_depends_on]

}




resource "aws_api_gateway_resource" "resource_get_object" {
  path_part   = "getObjects"
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.api.id
}

output "aws_api_gateway_resource_path_get_object" {
  value = aws_api_gateway_resource.resource_get_object.path

}

# ----- REQUEST

locals {
  http_method_get_object = "GET"
}

output "http_method_get_object" {
  value = local.http_method_get_object
}

resource "aws_api_gateway_method" "method_request_get_object" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource_get_object.id
  http_method   = local.http_method_get_object
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.gateway_authorizer_get_object.id
  authorization_scopes = ["email"]

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# output "aws_api_gateway_method_http_method" {
#   value = aws_api_gateway_method.method.http_method

# }

resource "aws_api_gateway_integration" "integration_request_get_object" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource_get_object.id
  http_method             = aws_api_gateway_method.method_request_get_object.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn_get_object
}


resource "aws_api_gateway_method_response" "method_response_get_object" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_get_object.id}"
  http_method = "${aws_api_gateway_method.method_request_get_object.http_method}"
  status_code = "200"
  # response_models = {
  #   "application/json" = "Empty"
  # }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.cors_get_object]
}

# -------------------------------------------------------------- CORS

# --- PUT TASK CORS
resource "aws_api_gateway_method" "cors_put_task" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_put_task.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_put_task" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_put_task.id}"
  http_method = "${aws_api_gateway_method.cors_put_task.http_method}"
  type = "MOCK"
  request_templates = {
    "application/json" = <<EOT
{"statusCode": 200}
EOT
  }
}

resource "aws_api_gateway_integration_response" "cors_put_task" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_put_task.id}"
  http_method = "${aws_api_gateway_method.cors_put_task.http_method}"
  status_code = "${aws_api_gateway_method_response.cors_put_task_200.status_code}"
        
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'${var.schema_http}://${var.domain}'", # replace with hostname of frontend (CloudFront)
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'PUT'" # remove or add HTTP methods as needed
  }

  depends_on = [aws_api_gateway_method_response.cors_put_task_200]
}

resource "aws_api_gateway_method_response" "cors_put_task_200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_put_task.id}"
  http_method = "${aws_api_gateway_method.cors_put_task.http_method}"
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}


# --- GET objectS CORS
resource "aws_api_gateway_method" "cors_get_object" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_get_object.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_get_object" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_get_object.id}"
  http_method = "${aws_api_gateway_method.cors_get_object.http_method}"
  type = "MOCK"
  request_templates = {
    "application/json" = <<EOT
{"statusCode": 200}
EOT
  }
}

resource "aws_api_gateway_integration_response" "cors_get_object" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_get_object.id}"
  http_method = "${aws_api_gateway_method.cors_get_object.http_method}"
  status_code = "${aws_api_gateway_method_response.cors_get_object_200.status_code}"
        
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'${var.schema_http}://${var.domain}'", # replace with hostname of frontend (CloudFront)
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET'" # remove or add HTTP methods as needed
  }

  depends_on = [aws_api_gateway_method_response.cors_get_object_200]

}

resource "aws_api_gateway_method_response" "cors_get_object_200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.resource_get_object.id}"
  http_method = "${aws_api_gateway_method.cors_get_object.http_method}"
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# ---- CORS headers to server-side errors

resource "aws_api_gateway_gateway_response" "response_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "DEFAULT_4XX"

  response_templates = {
    "application/json" = "{'message':$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${var.schema_http}://${var.domain}'" # replace with hostname of frontend (CloudFront)
  }
}

resource "aws_api_gateway_gateway_response" "response_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "DEFAULT_5XX"

  response_templates = {
    "application/json" = "{'message':$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${var.schema_http}://${var.domain}'" # replace with hostname of frontend (CloudFront)
  }
}

# -------------------

resource "aws_api_gateway_deployment" "lambda" {
  # depends_on = [
  #   aws_api_gateway_integration.integration_request_put_task,
  #   aws_api_gateway_integration.integration_request_get_object,
  #   aws_api_gateway_integration_response.cors_put_task,
  #   aws_api_gateway_integration_response.cors_get_object
  #   ]
    # aws_api_gateway_integration_response.integration_response_put_task,
    # aws_api_gateway_integration_response.integration_response_get_object
    

  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  #stage_name  = "prod"
  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.resource_get_object.id,
      aws_api_gateway_resource.resource_put_task.id,
      aws_api_gateway_method.method_request_put_task.id,
      aws_api_gateway_method.method_request_get_object.id,
      aws_api_gateway_integration.cors_get_object.id,
      aws_api_gateway_integration.cors_put_task.id,
      aws_api_gateway_integration.integration_request_get_object.id,
      aws_api_gateway_integration.integration_request_put_task.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_method_settings" "general_settings" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${aws_api_gateway_stage.prod.stage_name}"
  method_path = "*/*"

  settings {
    # Enable CloudWatch logging and metrics
    metrics_enabled        = true
    # data_trace_enabled     = true
    logging_level          = "ERROR"

    # Limit the rate of calls to prevent abuse and unwanted charges
    throttling_rate_limit  = 100
    throttling_burst_limit = 50
  }
}

resource "aws_api_gateway_stage" "prod" {
  depends_on = [aws_cloudwatch_log_group.rest_api]
  stage_name    = "prod"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  deployment_id = "${aws_api_gateway_deployment.lambda.id}"
  # variables = {
  #   "lbfunc" = "${var.lambda_name}"
  # }
}

output "invoke_url" {
  value = aws_api_gateway_deployment.lambda.invoke_url
}

resource "aws_cloudwatch_log_group" "rest_api" {
  name              = "/aws/apigateway/API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/prod"
  retention_in_days = var.retention_time
  # ... potentially other configuration ...
}

resource "aws_api_gateway_account" "rest_api" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "default"
  role = aws_iam_role.cloudwatch.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}