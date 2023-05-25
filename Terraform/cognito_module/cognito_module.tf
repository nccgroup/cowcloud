variable "domain" { }
variable "random_value" {}
variable "schema_http" { }

resource "aws_iam_role" "group_role" {
  name = "user-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "us-east-1:12345678-dead-beef-cafe-123456790ab"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF
}


resource "aws_cognito_resource_server" "resource" {
  identifier = "${var.schema_http}://${var.domain}"
  name       = "${var.domain}"


  user_pool_id = "${aws_cognito_user_pool.pool.id}"
}

# resource "aws_acm_certificate" "cert" {
#   domain_name       = "${var.domain}"
#   validation_method = "DNS"

#   tags = {
#     Environment = "test"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_cognito_user_pool_domain" "main" {
  #domain       = "${replace(var.domain, ".", "")}-3jd93hf"
  domain  = "cogn1to-domain-${var.random_value}-cowcloud"
  #certificate_arn = "${aws_acm_certificate.cert.arn}"
  user_pool_id = "${aws_cognito_user_pool.pool.id}"
}


output "aws_cognito_user_pool_domain_domain" {
  value = aws_cognito_user_pool_domain.main.domain
}


output "cognito_user_pool_name" {
  value = "${aws_cognito_user_pool.pool.name}"
}

output "cognito_pool_depends_on" {
  value = aws_cognito_user_pool.pool
}

resource "aws_cognito_user_pool" "pool" {
  name = "pool"
  
  
  alias_attributes                                   = ["email", "preferred_username"]
  auto_verified_attributes                           = ["email"]
  #username_attributes                                = ["email"] 
  email_verification_subject                         = "Your Verification Code"
  email_verification_message                         = "Please use the following code: {####}"
  #lambda_config_verify_auth_challenge_response       = "arn:aws:lambda:us-east-1:123456789012:function:my_lambda_function"

  # MESSAGE CUSTOMIZATIONS
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_message_by_link = "Your life will be dramatically improved by signing up! {##Click Here##}"
    email_subject_by_link = "Welcome to to a new world and life!"
  }

  email_configuration {
    #reply_to_email_address = "a-email-for-people-to@${var.domain}"
    email_sending_account = "COGNITO_DEFAULT"
  }

  password_policy {
    minimum_length    = 10
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  
  user_pool_add_ons {
    advanced_security_mode = "OFF"
  }


  schema {
    name                = "email"
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable             = false
    required            = true

    string_attribute_constraints {
      min_length = 5
      max_length = 2048
    }
  }
}


resource "aws_cognito_user_pool_client" "client" {
  name = "client"

  user_pool_id = "${aws_cognito_user_pool.pool.id}"

  generate_secret                      = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = "true"
  allowed_oauth_scopes                 = ["email", "openid", "phone", "profile", "aws.cognito.signin.user.admin"]
  # The access token can only be used against Amazon Cognito user pools if an aws.cognito.signin.user.admin scope is requested. 
  callback_urls                        = ["${var.schema_http}://${var.domain}"]
  default_redirect_uri                 = "${var.schema_http}://${var.domain}"
  #explicit_auth_flows                 = ["USER_PASSWORD_AUTH"]
  logout_urls                          = ["${var.schema_http}://${var.domain}"]
  read_attributes                      = ["email", "phone_number"]
  refresh_token_validity               = 60
  supported_identity_providers         = ["COGNITO"]
  write_attributes                     = ["email",]

}


resource "aws_cognito_user_group" "main" {
  name         = "user-group"
  user_pool_id = "${aws_cognito_user_pool.pool.id}"
  description  = "Managed by Terraform"
  precedence   = 42
  role_arn     = "${aws_iam_role.group_role.arn}"
}





output "aws_cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "aws_cognito_user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}

# ------------------------------------------------------------------------------------


# TO USE TWO AUTHORIZERS (implicit+code and client_credentials) A LAMBDA AUTHORIZER WOULD BE REQUIRED, COGNITO IS CURRENTLY USED AS AUTHORIZER FOR THE TWO GATEWAY METHODS.
variable "cognito_client_credentials_enabled" {
  default = false
}

resource "aws_cognito_user_pool" "pool2" {
  count = var.cognito_client_credentials_enabled == true ? 1 : 0
  name = "pool2"
  alias_attributes                                   = ["preferred_username"]
  password_policy {
    minimum_length    = 10
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
 
}


resource "aws_cognito_user_pool_client" "client2" {
  count = var.cognito_client_credentials_enabled == true ? 1 : 0
  name = "client_crendentials"

  user_pool_id = "${aws_cognito_user_pool.pool2[0].id}"

  generate_secret                      = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = aws_cognito_resource_server.resource2[0].scope_identifiers
  # The access token can only be used against Amazon Cognito user pools if an aws.cognito.signin.user.admin scope is requested. 
  callback_urls                        = ["${var.schema_http}://${var.domain}"]
  refresh_token_validity               = 30
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

}


resource "aws_cognito_resource_server" "resource2" {
  count = var.cognito_client_credentials_enabled == true ? 1 : 0
  identifier = "${var.schema_http}://${var.domain}"
  name       = "${var.domain}"
  user_pool_id = aws_cognito_user_pool.pool2[0].id
  scope {
    scope_name        = "all"
    scope_description = "Get access to all API Gateway endpoints."
  }

}


resource "aws_cognito_user_pool_domain" "client_credentials" {
  count = var.cognito_client_credentials_enabled == true ? 1 : 0
  domain  = "cogn1to-domain-${var.random_value}-cowcloud-cc"
  user_pool_id = "${aws_cognito_user_pool.pool2[0].id}"
}
