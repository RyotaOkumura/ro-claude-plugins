/**
 * Cloudflare Workers - R2 Image Proxy with Token Authentication
 *
 * This worker serves images from a private R2 bucket with simple token-based auth.
 * The token is passed as a query parameter: ?token=SECRET_TOKEN
 */

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS headers for browser compatibility
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only allow GET and HEAD methods
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: corsHeaders
      });
    }

    // Token authentication
    const providedToken = url.searchParams.get('token');
    const validToken = env.AUTH_TOKEN;

    if (!providedToken || providedToken !== validToken) {
      return new Response('Unauthorized', {
        status: 401,
        headers: corsHeaders
      });
    }

    // Extract the object key from the path (remove leading slash)
    const objectKey = url.pathname.slice(1);

    if (!objectKey) {
      return new Response('Not Found', {
        status: 404,
        headers: corsHeaders
      });
    }

    try {
      // Fetch the object from R2
      const object = await env.R2_BUCKET.get(objectKey);

      if (!object) {
        return new Response('Not Found', {
          status: 404,
          headers: corsHeaders
        });
      }

      // Build response headers
      const headers = new Headers();

      // Set content type from R2 metadata or infer from extension
      const contentType = object.httpMetadata?.contentType || inferContentType(objectKey);
      headers.set('Content-Type', contentType);

      // Set cache headers for performance
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');

      // Set ETag for caching
      headers.set('ETag', object.httpEtag);

      // Set content length if available
      if (object.size) {
        headers.set('Content-Length', object.size.toString());
      }

      // Add CORS headers
      Object.entries(corsHeaders).forEach(([key, value]) => {
        headers.set(key, value);
      });

      // Handle conditional requests (If-None-Match)
      const ifNoneMatch = request.headers.get('If-None-Match');
      if (ifNoneMatch && ifNoneMatch === object.httpEtag) {
        return new Response(null, {
          status: 304,
          headers
        });
      }

      // Return the image
      return new Response(object.body, { headers });

    } catch (error) {
      console.error('R2 fetch error:', error);
      return new Response('Internal Server Error', {
        status: 500,
        headers: corsHeaders
      });
    }
  }
};

/**
 * Infer content type from file extension
 */
function inferContentType(filename) {
  const ext = filename.split('.').pop()?.toLowerCase();
  const mimeTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'bmp': 'image/bmp',
  };
  return mimeTypes[ext] || 'application/octet-stream';
}
