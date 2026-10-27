import { ajax } from "discourse/lib/ajax";
import { withoutPrefix } from "discourse/lib/get-url";

export const JSON_API_VERSION = "2026-08-31";

// Matched by URL, not by a request option: paging links (`document.next()`)
// issue a bare `{ url, method }` request.
function isJsonApiUrl(url) {
  return withoutPrefix(
    new URL(url, window.location.origin).pathname
  ).startsWith("/api/");
}

const jsonApiHandler = {
  async request(context, next) {
    const request = context.request;
    if (!request.url || !isJsonApiUrl(request.url)) {
      return next(request);
    }

    return ajax(request.url, {
      type: request.method,
      headers: { "Api-Version": JSON_API_VERSION },
    });
  },
};

export default jsonApiHandler;
