
variable "s3bucket_name_ec2repository" { }
variable "s3bucket_name_results_storage" { }
# results_storage
variable "s3bucket_name_website" { }
# uncomment after DEBUG
variable "cloudfront_origin_access_identity_iam_arn" { }
variable "cidr_whitelist" { }
variable "retention_time" { }

resource "aws_s3_bucket" "tasks" {
  bucket = var.s3bucket_name_results_storage
  
  force_destroy = true

  versioning {
      enabled = true
  }

  lifecycle_rule {
    id      = "task_expiration"
    enabled = true

    tags = {
      Key      = "Report"
    }

    expiration {
      days = var.retention_time
    }
  }

}

# resource "aws_s3control_bucket" "tasks_expiration" {
#   bucket     = var.s3bucket_name_results_storage
#   outpost_id = data.aws_outposts_outpost.example.id
# }

# resource "aws_s3control_bucket_policy" "example" {
#   bucket = aws_s3control_bucket.tasks_expiration.arn
#   policy = jsonencode({
#     Id = "testBucketPolicy"
#     Statement = [
#       {
#         Action = "s3-outposts:PutBucketLifecycleConfiguration"
#         Effect = "Allow"
#         Principal = {
#           AWS = "*"
#         }
#         Resource = aws_s3control_bucket.example.arn
#         Sid      = "statement1"
#       }
#     ]
#     Version = "2012-10-17"
#   })
# }

# data "aws_outposts_outpost" "example" {
#   name = var.s3bucket_name_results_storage
# }

# resource "aws_s3control_bucket_lifecycle_configuration" "tasks_expiration_rule" {
#   bucket = aws_s3control_bucket.tasks_expiration.arn

#   rule {
#     expiration {
#       days = var.retention_time
#     }

#     id = "tasks_expiration"
#   }

# }

output "s3bucket_name_results_storage" {
  value = aws_s3_bucket.tasks.bucket
}

output "s3bucket_arn_results_storage" {
  value = aws_s3_bucket.tasks.arn
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.tasks.id

  block_public_acls   = true
  block_public_policy = true

  depends_on = [
    aws_s3_bucket_policy.s3_scan_policy
  ]


}

resource "aws_s3_bucket_policy" "s3_scan_policy" {
  bucket = aws_s3_bucket.tasks.id

  policy = (length(var.cidr_whitelist) > 0) ? jsonencode({
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid":"PublicRead",
        "Effect":"Allow",
        "Principal": "*",
        "Action":"s3:GetObject",
        "Resource":[
          "${aws_s3_bucket.tasks.arn}/*",
        ],
        "Condition" : {
          "IpAddress" : {
              "aws:SourceIp": var.cidr_whitelist
          }
        }
      }]
  }) : jsonencode({
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid":"PublicRead",
        "Effect":"Allow",
        "Principal": "*",
        "Action":"s3:GetObject",
        "Resource":[
          "${aws_s3_bucket.tasks.arn}/*",
        ]
      }]
  })

}

# --------------- EC2APP CODE REPOSITORY


resource "aws_s3_bucket" "ec2app_repository" {
  bucket = var.s3bucket_name_ec2repository
  
  force_destroy = true

  versioning {
      enabled = true
  }
}

output "s3bucket_name_ec2repository" {
  value = aws_s3_bucket.ec2app_repository.bucket
}

output "s3bucket_arn_ec2repository" {
  value = aws_s3_bucket.ec2app_repository.arn
}



# --------------- FRONT-END



# # AWS S3 bucket for static hosting
resource "aws_s3_bucket" "website" {
  bucket = var.s3bucket_name_website
  acl = "public-read"

  force_destroy = true
#   cors_rule {
#     allowed_headers = ["*"]
#     allowed_methods = ["PUT","POST"]
#     allowed_origins = ["*"]
#     expose_headers = ["ETag"]
#     max_age_seconds = 3000
#   }

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForGetBucketObjects",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${var.s3bucket_name_website}/*"
    }
  ]
}
EOF

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}



output "aws_s3_bucket_website_domain_name" {
  value       = aws_s3_bucket.website.bucket
}



# data "aws_iam_policy_document" "s3_policy_website" {
#   statement {
#     actions   = ["s3:GetObject"]
#     resources = ["${aws_s3_bucket.website.arn}/*"]

#     principals {
#       type        = "AWS"
#       identifiers = ["${var.cloudfront_origin_access_identity_iam_arn}"]
#     }
#   }
# }

resource "aws_s3_bucket_policy" "s3_policy_website" {
  bucket = aws_s3_bucket.website.id

  # "Principal": "*", # UNCOMMENT THIS TO RESTRICT THE TRAFFIC AND ONLY ALLOW CLOUDFRONT TO ACCESS THIS BUCKET ! "${var.cloudfront_origin_access_identity_iam_arn}"
  policy = jsonencode({
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid":"PublicRead",
        "Effect":"Allow",
        "Principal": { "AWS": ["${var.cloudfront_origin_access_identity_iam_arn}"]},
        "Action":"s3:GetObject",
        "Resource":[
          "${aws_s3_bucket.website.arn}/*",
        ]
      }]
  })

}


# resource "aws_s3_bucket_policy" "example" {
#   bucket = "${aws_s3_bucket.website.id}"
#   #policy = "${data.aws_iam_policy_document.s3_policy_website.json}"
#   policy = "${aws_iam_policy.s3_policy_website.json}"
# }