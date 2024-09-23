+++
title = 'Deploying Hugo Websites to AWS CloudFront and S3 for Faster Content Delivery'
date = 2024-09-14T23:40:27-07:00
# draft = true
# I like this by default now... keeps the page full width with tags below.
hideAsideBar = true
# homeFeatureWide = true
homeFeature = true
homeFeatureIcon = "fa-solid fa-code-merge"
# summary = ""
# # categories = [""]
tags = [
  "hugo",
  "aws",
  "cloudfront",
  "static site deployment",
  "s3"
  ]
# featured_image = ""
# showTOC = true
+++

## A new way to deploy my hugo websites

> A simple and cost-effective approach to deploying Hugo projects to AWS CloudFront.

I have and still do use services like AWS Amplify and Netlify to automate my CI/CD pipeline for many of my projects, triggered by a GitHub check-in and running in GitHub Actions. However, for a recent photography project that involved deploying a large number of files, storing everything in GitHub wasn't feasible. I needed a solution that was simple, affordable, and delivered high performance. That's when I decided to use AWS CloudFront with an S3 bucket, integrated with an SSL certificate generated through CloudFront.

### Why AWS CloudFront?

<!--more-->

AWS CloudFront with S3 allows you to host and serve static files at scale while benefiting from fast, globally distributed content delivery. By using CloudFront's built-in SSL support and caching mechanisms, you can ensure that your Hugo site is both secure and lightning fast for visitors across the globe.

### Hugo's Built-in Deployment Feature

Hugo has a built-in deploy option that simplifies the process of deploying to AWS. I leveraged this alongside some AWS CLI scripting to ensure I was logged into the correct AWS profile and could deploy and invalidate the cache with a single command: `./deploy.sh`.

### Setting Up Hugo for Deployment

First, you'll need to set up your Hugo configuration for deployment. You can include the configuration under the deployment key in config.toml, or if you have a more distributed setup, you can create a separate deployment.toml file.

Here’s an example in `deployment.toml`:

```toml
[[targets]]
  # An arbitrary name for this target.
  name = "production"
  URL = "s3://<YOUR-S3-BUCKET-URL>.com?region=us-east-2"
  cloudFrontDistributionID = "<YOUR-CLOUDFRONT-DISTRIBUTION-ID>"

[[matchers]]
  pattern = "^.+\\.(js|css|svg|ttf|woff|woff2|eot|png|gif|pdf)$"
  cacheControl = "max-age=630720000, no-transform, public"
  gzip = true

[[matchers]]
  pattern = "^.+\\.(html|xml|json)$"
  gzip = true
```

### Deploy Script

Here’s the deploy.sh script I use. It switches AWS credentials based on the profile I want to deploy under and performs the deployment with cache invalidation:

You will need the AWS CLI installed and AWS profiles setup to use this script.

```bash
#!/bin/bash

SITE_NAME=<YOUR-SITE-NAME>
BASE_DIR=<PATH-TO-YOUR-SITE>
CLOUDFRONT_ID=<YOUR-CLOUDFRONT-DISTRIBUTION-ID>
AWS_CREDENTIALS_FILE=~/.aws/credentials
PROFILE=<YOUR-AWS-PROFILE-NAME> # Change this to 'another one' if needed

# Function to save the original default profile credentials
save_default_credentials() {
    # Extract the original aws_access_key_id and aws_secret_access_key from the default profile
    ORIGINAL_AWS_ACCESS_KEY_ID=$(awk '/^\[default\]/ {flag=1; next} /^\[/ {flag=0} flag && /aws_access_key_id/ {print $3}' "$AWS_CREDENTIALS_FILE")
    ORIGINAL_AWS_SECRET_ACCESS_KEY=$(awk '/^\[default\]/ {flag=1; next} /^\[/ {flag=0} flag && /aws_secret_access_key/ {print $3}' "$AWS_CREDENTIALS_FILE")
    
    if [ -z "$ORIGINAL_AWS_ACCESS_KEY_ID" ] || [ -z "$ORIGINAL_AWS_SECRET_ACCESS_KEY" ]; then
        echo "Could not extract original AWS credentials from the default profile."
        exit 1
    fi
}

# Function to restore the original default profile credentials
restore_default_credentials() {
    if [ -n "$ORIGINAL_AWS_ACCESS_KEY_ID" ] && [ -n "$ORIGINAL_AWS_SECRET_ACCESS_KEY" ]; then
        sed -i.bak -e "/^\[default\]/,/^\[/ s/aws_access_key_id = .*/aws_access_key_id = $ORIGINAL_AWS_ACCESS_KEY_ID/" \
                   -e "/^\[default\]/,/^\[/ s/aws_secret_access_key = .*/aws_secret_access_key = $ORIGINAL_AWS_SECRET_ACCESS_KEY/" \
                   "$AWS_CREDENTIALS_FILE"
        echo "AWS credentials for 'default' profile restored to original settings."
    fi
}

# Function to copy credentials from selected profile to default
copy_aws_credentials() {
    # Check if the profile exists in the credentials file
    if ! grep -q "^\[$PROFILE\]" "$AWS_CREDENTIALS_FILE"; then
        echo "Profile '$PROFILE' not found."
        exit 1
    fi
    
    # Extract the aws_access_key_id and aws_secret_access_key from the selected profile
    AWS_ACCESS_KEY_ID=$(awk "/^\[$PROFILE\]/ {flag=1; next} /^\[/ {flag=0} flag && /aws_access_key_id/ {print \$3}" "$AWS_CREDENTIALS_FILE")
    AWS_SECRET_ACCESS_KEY=$(awk "/^\[$PROFILE\]/ {flag=1; next} /^\[/ {flag=0} flag && /aws_secret_access_key/ {print \$3}" "$AWS_CREDENTIALS_FILE")
    
    # If variables are empty, exit with an error message
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Could not extract AWS credentials from profile '$PROFILE'."
        exit 1
    fi

    # Update default profile safely with correct credentials
    if grep -q "^\[default\]" "$AWS_CREDENTIALS_FILE"; then
        # Modify the existing default profile in place
        sed -i.bak -e "/^\[default\]/,/^\[/ s/aws_access_key_id = .*/aws_access_key_id = $AWS_ACCESS_KEY_ID/" \
                   -e "/^\[default\]/,/^\[/ s/aws_secret_access_key = .*/aws_secret_access_key = $AWS_SECRET_ACCESS_KEY/" \
                   "$AWS_CREDENTIALS_FILE"
    else
        # If default profile doesn't exist, add it to the end of the file
        echo -e "\n[default]\naws_access_key_id = $AWS_ACCESS_KEY_ID\naws_secret_access_key = $AWS_SECRET_ACCESS_KEY" >> "$AWS_CREDENTIALS_FILE"
    fi

    echo "AWS credentials for '$PROFILE' copied to 'default' profile."
}

# Save the original default credentials
save_default_credentials

# Copy the AWS credentials to default
copy_aws_credentials

# Deploy the Hugo site
rm -rf "$BASE_DIR/public"
hugo --minify --gc
hugo deploy --invalidateCDN
# echo "Invalidating CloudFront cache..."
# aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*" > /dev/null
echo "Site $SITE_NAME deployed successfully!"

# Restore the original default credentials
restore_default_credentials

```