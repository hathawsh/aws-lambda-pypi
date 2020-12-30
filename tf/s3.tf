resource "aws_s3_bucket" "pypicloud" {
  bucket = var.package_bucket
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "pypicloud" {
  bucket = aws_s3_bucket.pypicloud.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
