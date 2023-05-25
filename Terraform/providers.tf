# setx AWS_ACCESS_KEY_ID AKI...
# setx AWS_SECRET_ACCESS_KEY /aadww+...
# setx AWS_DEFAULT_REGION us-east-1
# cmd, setx AWS_DEFAULT_REGION ""
# aws sts assume-role --role-arn arn:aws:iam::863994147283:role/ec2_lambda_access_role --role-session-name workers --profile bob
# https://iam.cloudonaut.io/reference/autoscaling.html

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"

}