# Cloudflare Workers Setup Guide

## Prerequisites

- Node.js 16+ installed
- Cloudflare account
- Wrangler CLI

## Step 1: Install Wrangler

```bash
npm install -g wrangler
```

## Step 2: Authenticate with Cloudflare

```bash
wrangler login
```

This will open a browser for OAuth authentication.

## Step 3: Navigate to Workers Directory

```bash
cd /path/to/plugins/notion-r2-image/workers
```

## Step 4: Configure wrangler.toml

Edit `wrangler.toml` and update the bucket name:

```toml
[[r2_buckets]]
binding = "R2_BUCKET"
bucket_name = "your-actual-bucket-name"  # <-- Change this
```

## Step 5: Set the Auth Token Secret

```bash
# Generate a secure token
TOKEN=$(openssl rand -hex 32)
echo "Your token: $TOKEN"

# Set it as a Worker secret
wrangler secret put AUTH_TOKEN
# When prompted, paste your token
```

**Important**: Save this token in your `~/.config/notion-r2-image/.env` as `WORKERS_AUTH_TOKEN`.

## Step 6: Deploy the Worker

```bash
wrangler deploy
```

After deployment, you'll see output like:
```
Published notion-r2-image-proxy (1.0s)
  https://notion-r2-image-proxy.your-subdomain.workers.dev
```

## Step 7: Update Configuration

Add the Worker URL to `~/.config/notion-r2-image/.env`:

```bash
WORKERS_PROXY_URL=https://notion-r2-image-proxy.your-subdomain.workers.dev
```

## Step 8: Test the Worker

```bash
# Upload a test image
/path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh /path/to/test.png

# The output URL should work when opened in a browser
```

## Custom Domain (Optional)

To use a custom domain instead of `*.workers.dev`:

1. Go to Cloudflare Dashboard > Workers & Pages
2. Select your worker
3. Go to Settings > Domains & Routes
4. Add a custom domain
5. Update `WORKERS_PROXY_URL` in your .env file

## Updating the Worker

After making changes to `image-proxy.js`:

```bash
cd /path/to/plugins/notion-r2-image/workers
wrangler deploy
```

## Viewing Logs

```bash
wrangler tail
```

## Local Development

```bash
wrangler dev
```

This starts a local server at `http://localhost:8787` for testing.

Note: Local development requires the `--remote` flag to use the actual R2 bucket:
```bash
wrangler dev --remote
```

## Changing the Auth Token

If your token is compromised:

1. Generate a new token:
   ```bash
   openssl rand -hex 32
   ```

2. Update the Worker secret:
   ```bash
   wrangler secret put AUTH_TOKEN
   # Paste the new token when prompted
   ```

3. Update `~/.config/notion-r2-image/.env`:
   ```bash
   WORKERS_AUTH_TOKEN=your_new_token
   ```

**Note**: Old URLs with the previous token will stop working immediately.

## Troubleshooting

### "401 Unauthorized"
- Check that AUTH_TOKEN secret is set: `wrangler secret list`
- Verify the token in your .env matches the Worker secret

### "404 Not Found"
- Ensure the image was uploaded successfully
- Check the object path matches what's in R2
- Use `wrangler r2 object list <bucket-name>` to list objects

### "500 Internal Server Error"
- Check Worker logs: `wrangler tail`
- Verify R2 bucket binding is correct in wrangler.toml
