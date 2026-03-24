# -----------------------------------------------------------------------------
# KMS Key for VPC Log Encryption (SC-12, SC-13, AU-9)
# -----------------------------------------------------------------------------

resource "aws_kms_key" "vpc_logs" {
  description             = "KMS key for ${var.vpc_name} VPC log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLogDeliveryService"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-vpc-logs-kms"
  })
}

resource "aws_kms_alias" "vpc_logs" {
  name          = "alias/${var.resource_prefix}-vpc-logs"
  target_key_id = aws_kms_key.vpc_logs.key_id
}

# -----------------------------------------------------------------------------
# S3 Bucket for VPC Flow Logs (AU-9, AU-11)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "flowlogs" {
  bucket = "${var.resource_prefix}-vpc-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-vpc-logs"
  })
}

resource "aws_s3_bucket_versioning" "flowlogs" {
  bucket = aws_s3_bucket.flowlogs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flowlogs" {
  bucket = aws_s3_bucket.flowlogs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.vpc_logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flowlogs" {
  bucket = aws_s3_bucket.flowlogs.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_lifecycle_configuration" "flowlogs" {
  bucket = aws_s3_bucket.flowlogs.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    transition {
      days          = var.flow_log_retention_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.flow_log_retention_days + var.flow_log_archive_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "flowlogs" {
  bucket = aws_s3_bucket.flowlogs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.flowlogs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"     = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowLogDeliveryBucketCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource = aws_s3_bucket.flowlogs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.flowlogs.arn,
          "${aws_s3_bucket.flowlogs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.flowlogs]
}

# -----------------------------------------------------------------------------
# VPC Flow Logs -> S3 (AU-2, AU-3, SC-7)
# Captures ALL traffic (ACCEPT + REJECT) with hourly partitioning.
# -----------------------------------------------------------------------------

resource "aws_flow_log" "this" {
  vpc_id                   = local.vpc_id
  log_destination          = aws_s3_bucket.flowlogs.arn
  log_destination_type     = "s3"
  traffic_type             = "ALL"
  max_aggregation_interval = var.flow_log_max_aggregation_interval

  destination_options {
    file_format                = "plain-text"
    per_hour_partition         = true
    hive_compatible_partitions = true
  }

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-vpc-flow-logs"
  })
}
