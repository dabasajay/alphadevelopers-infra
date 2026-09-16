terraform {
  # OpenTofu 1.10+ / Terraform 1.10+ for S3 native state locking (use_lockfile)
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.18+ carries the Bedrock AgentCore resources.
      version = "~> 6.62"
    }
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.5"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
