# Notion R2 Image - Setup Guide

## Overview

This plugin allows you to upload images to a private Cloudflare R2 bucket and get URLs that can be embedded in Notion pages.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │────>│ upload_to_r2.sh  │────>│   Cloudflare    │
│  (invokes)      │     │ (AWS Sig V4)     │     │   R2 Bucket     │
└─────────────────┘     └──────────────────┘     │   (PRIVATE)     │
                                                 └────────┬────────┘
                                                          │
┌─────────────────┐     ┌──────────────────┐              │
│   Notion Page   │<────│ Workers Proxy    │<─────────────┘
│  (embeds URL)   │     │ (token auth)     │
└─────────────────┘     └──────────────────┘
```

## Prerequisites

- Cloudflare account with R2 enabled
- Cloudflare Workers (free tier is sufficient)
- macOS/Linux with bash, curl, and openssl

## Step 1: Create R2 Bucket

1. Log in to Cloudflare Dashboard
2. Go to **R2** in the sidebar
3. Click **Create bucket**
4. Name your bucket (e.g., `notion-images`)
5. Keep the bucket **private** (no public access)

## Step 2: Generate R2 API Credentials

1. In Cloudflare Dashboard, go to **R2** > **Manage R2 API Tokens**
2. Click **Create API Token**
3. Set permissions:
   - **Object Read & Write** for your bucket
4. Copy the **Access Key ID** and **Secret Access Key**

## Step 3: Create Configuration Directory

```bash
mkdir -p ~/.config/notion-r2-image
```

## Step 4: Create Configuration File

Create `~/.config/notion-r2-image/.env`:

```bash
# Cloudflare R2 credentials
R2_ACCESS_KEY_ID=your_access_key_here
R2_SECRET_ACCESS_KEY=your_secret_key_here
R2_BUCKET_NAME=notion-images
R2_ACCOUNT_ID=your_cloudflare_account_id

# Workers proxy configuration
# (Set these after deploying the Worker - see WORKERS_SETUP.md)
WORKERS_PROXY_URL=https://notion-r2-image-proxy.your-subdomain.workers.dev
WORKERS_AUTH_TOKEN=your_secure_random_token
```

### Finding Your Account ID

Your Account ID is in the Cloudflare Dashboard URL or in:
- Dashboard > Overview > Account ID (right sidebar)

### Generating a Secure Token

```bash
openssl rand -hex 32
```

## Step 5: Deploy Cloudflare Worker

See [WORKERS_SETUP.md](./WORKERS_SETUP.md) for detailed instructions.

## Step 6: Set File Permissions

Protect your credentials:

```bash
chmod 600 ~/.config/notion-r2-image/.env
```

## Step 7: Test the Setup

```bash
# Make the script executable
chmod +x /path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh

# Test upload
/path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh /path/to/test-image.png
```

## Troubleshooting

### "Config file not found"
- Ensure `~/.config/notion-r2-image/.env` exists
- Check file permissions: `chmod 600 ~/.config/notion-r2-image/.env`

### "SignatureDoesNotMatch" error
- Verify R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY are correct
- Ensure there are no extra spaces or newlines in the .env file

### "403 Forbidden" from Worker
- Check that AUTH_TOKEN matches in both .env and Worker secret
- Verify the bucket name in wrangler.toml matches R2_BUCKET_NAME

### Image not displaying in Notion
- Ensure the Worker is deployed and accessible
- Check that the URL includes the correct token
- Try opening the URL directly in a browser first

## Cost (Free Tier)

| Item | Free Tier | Overage |
|------|-----------|---------|
| Workers Requests | 100,000/day | $0.50/million |
| R2 Reads | 10 million/month | $0.36/million |
| R2 Storage | 10GB | $0.015/GB |

For personal/research use, the free tier is more than sufficient.
