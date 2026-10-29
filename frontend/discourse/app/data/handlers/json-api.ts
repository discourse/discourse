import type { Handler, NextFn } from "@warp-drive/core/request";
import type { RequestContext } from "@warp-drive/core/types/request";
import { ajax } from "discourse/lib/ajax";
import { withoutPrefix } from "discourse/lib/get-url";

export const JSON_API_VERSION = "2026-08-31";

// Matched by URL, not by a request option: paging links (`document.next()`)
// issue a bare `{ url, method }` request.
function isJsonApiUrl(url: string): boolean {
  return withoutPrefix(
    new URL(url, window.location.origin).pathname
  ).startsWith("/api/");
}

const jsonApiHandler: Handler = {
  // The handler contract is generic over the content a caller expects; this
  // one resolves to the JSON:API document the server sent.
  async request<T>(context: RequestContext, next: NextFn<T>) {
    const request = context.request;
    if (!request.url || !isJsonApiUrl(request.url)) {
      return next(request);
    }

    return ajax(request.url, {
      type: request.method,
      headers: { "Api-Version": JSON_API_VERSION },
    }) as Promise<T>;
  },
};

export default jsonApiHandler;
