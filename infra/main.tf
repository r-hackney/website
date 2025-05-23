## Version and provider block. ###

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

### Create an S3 bucket, make it publicly read accessible, and set it to website mode. ###

resource "aws_s3_bucket" "my_test_website_bucket" {
    bucket = "rhackney.net"
    force_destroy = true
}

resource "aws_s3_bucket_policy" "public_access" {
    bucket = aws_s3_bucket.my_test_website_bucket.id
    policy = data.aws_iam_policy_document.public_access_for_site.json

    depends_on = [ aws_s3_bucket_public_access_block.allow_public_access ]
}

resource "aws_s3_bucket_website_configuration" "website_config" {
    bucket = aws_s3_bucket.my_test_website_bucket.id

    index_document {
        suffix = "index.html"
    }
}

resource "aws_s3_bucket_public_access_block" "allow_public_access" {
    bucket = aws_s3_bucket.my_test_website_bucket.id

    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

### Create an A record in Route53 and point it at our bucket. ###

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.primary.zone_id   # your public zone
  name    = ""                                      # apex record
  type    = "A"

  alias {
    name = aws_s3_bucket_website_configuration.website_config.website_domain
    zone_id = aws_s3_bucket.my_test_website_bucket.hosted_zone_id
    evaluate_target_health = false
  }
}

### Find our Route53 domain so we can find the zone_id later. ###

data "aws_route53_zone" "primary" {
  name = "rhackney.net."
  private_zone = false
}

### Create our bucket policy. ###

data "aws_iam_policy_document" "public_access_for_site" {
    statement {
        effect = "Allow"
        principals {
            type = "AWS"
            identifiers = ["*"]
        }
        actions = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.my_test_website_bucket.arn}/*"]
    }
}