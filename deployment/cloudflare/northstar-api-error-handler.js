const DEFAULT_ORIGIN_HOST = "n8n.example.com";

export default {
  async fetch(request, env) {
    const incomingUrl = new URL(request.url);

    const originHost = env?.ORIGIN_HOST || DEFAULT_ORIGIN_HOST;

    const allowedPaths = new Set([
      "/webhook-test/lead-intake",
      "/webhook/lead-intake"
    ]);

    if (
      request.method !== "POST" ||
      !allowedPaths.has(incomingUrl.pathname)
    ) {
      return new Response("Not Found", { status: 404 });
    }

    const MAX_BODY_BYTES = 32 * 1024;

    const payloadTooLarge = () => new Response(
      JSON.stringify({
        success: false,
        data: null,
        error: {
          code: "PAYLOAD_TOO_LARGE",
          message: "Request body exceeds the allowed size."
        }
      }),
      {
        status: 413,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-store"
        }
      }
    );

    const contentLength = request.headers.get("content-length");

    if (contentLength !== null) {
      const declaredLength = Number(contentLength);

      if (
        !Number.isSafeInteger(declaredLength) ||
        declaredLength < 0 ||
        declaredLength > MAX_BODY_BYTES
      ) {
        return payloadTooLarge();
      }
    }

    const reader = request.clone().body?.getReader();
    let totalBytes = 0;

    if (reader) {
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          totalBytes += value.byteLength;

          if (totalBytes > MAX_BODY_BYTES) {
            await reader.cancel();
            return payloadTooLarge();
          }
        }
      } finally {
        reader.releaseLock();
      }
    }
    let upstreamRequest = request;

    // workers.dev testing: forward to the actual n8n hostname.
    // Worker Route: fetch the original request to the origin.
    if (incomingUrl.hostname !== originHost) {
      const originUrl = new URL(request.url);
      originUrl.protocol = "https:";
      originUrl.hostname = originHost;
      originUrl.port = "";

      upstreamRequest = new Request(originUrl, request);
    }

    const response = await fetch(upstreamRequest);

    if (response.status !== 422) {
      return response;
    }

    const contentType = response.headers.get("content-type") || "";

    if (!contentType.toLowerCase().includes("application/json")) {
      return response;
    }

    let errorBody;

    try {
      errorBody = await response.clone().json();
    } catch {
      return response;
    }

    if (
      errorBody?.code !== 422 ||
      errorBody?.message !== "Failed to parse request body"
    ) {
      return response;
    }

    return new Response(
      JSON.stringify({
        success: false,
        data: null,
        error: {
          code: "BAD_JSON",
          message: "Malformed JSON request body."
        }
      }),
      {
        status: 400,
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-store"
        }
      }
    );
  }
};
