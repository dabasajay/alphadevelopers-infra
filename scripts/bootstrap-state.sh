#!/usr/bin/env bash
# Creates the Terraform state bucket. Run once; the bucket cannot be managed
# by the state it holds. Everything else lives in Terraform.
set -euo pipefail

BUCKET="${TF_STATE_BUCKET:-alphadevelopers-tfstate}"
REGION="${AWS_REGION:-ap-south-1}"
PROFILE="${AWS_PROFILE:?set AWS_PROFILE}"

aws() { command aws --profile "$PROFILE" --region "$REGION" "$@"; }

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "bucket $BUCKET already exists"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --create-bucket-configuration "LocationConstraint=$REGION"
  echo "created $BUCKET"
fi

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# SSE-S3 rather than a KMS CMK: same encryption at rest, no $1/month key charge
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"DenyInsecureTransport\",
    \"Effect\": \"Deny\",
    \"Principal\": \"*\",
    \"Action\": \"s3:*\",
    \"Resource\": [\"arn:aws:s3:::$BUCKET\", \"arn:aws:s3:::$BUCKET/*\"],
    \"Condition\": {\"Bool\": {\"aws:SecureTransport\": \"false\"}}
  }]
}"

# State versions accumulate; expire old ones but keep enough to recover
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-noncurrent-state",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
    }]
  }'

echo "state bucket ready: s3://$BUCKET (region $REGION)"
