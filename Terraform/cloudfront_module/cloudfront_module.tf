variable "domain_name" { }
variable "cidr_whitelist" {}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.s3_distribution.id
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {

        origin_id   = "default"
        domain_name = "${var.domain_name}.s3.amazonaws.com"
    
        s3_origin_config {
        origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }
 # count = 
  web_acl_id = (length(var.cidr_whitelist) > 0) ? aws_waf_web_acl.waf_acl[0].id : null

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Added authentication to bucket"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "default"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}

output "cloudfront_origin_access_identity_iam_arn" {
    value =  aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn

}

output "aws_cloudfront_distribution_domain_name" {
    value = aws_cloudfront_distribution.s3_distribution.domain_name
}


# --------------------- WAF

# the name of the CloudWatch metric
variable "metric_name" {
  default = "cloudFront"
}

# the name of the ACL
variable "acl_id" {
  default = "waf_acl"
}


resource "aws_waf_web_acl" "waf_acl" {
  count = (length(var.cidr_whitelist) > 0) ? 1 : 0
  name        = "${var.acl_id}_waf_acl"
  metric_name = "${var.metric_name}wafacl"

  default_action {
    type = "BLOCK"
  }

  rules {
    priority = 10
    rule_id  = aws_waf_rule.ip_whitelist[0].id

    action {
      type = "ALLOW"
    }
  }

  depends_on = [
    aws_waf_rule.ip_whitelist,
    aws_waf_ipset.ip_whitelist
  ]
}

resource "aws_waf_rule" "ip_whitelist" {
  count = (length(var.cidr_whitelist) > 0) ? 1 : 0
  name        = "${var.acl_id}_ip_whitelist_rule"
  metric_name = "${var.metric_name}ipwhitelist"
  
  depends_on = [aws_waf_ipset.ip_whitelist]
  
  predicates {
    data_id = aws_waf_ipset.ip_whitelist[0].id
    negated = false
    type    = "IPMatch"
  }

}

resource "aws_waf_ipset" "ip_whitelist" {
  count = (length(var.cidr_whitelist) > 0) ? 1 : 0
  name = "${var.acl_id}_match_ip_whitelist"
  
  # dynamic below generates this from the list
  #
  # ip_set_descriptors {
  #   type = "IPV4"
  #   value = "8.8.8.8/32"
  # }

  dynamic "ip_set_descriptors" {
    for_each = toset(var.cidr_whitelist)

    content {
      type  = "IPV4"
      value = ip_set_descriptors.key
    }
  }
}