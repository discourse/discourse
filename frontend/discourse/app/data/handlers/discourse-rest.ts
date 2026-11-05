import type { Handler, NextFn } from "@warp-drive/core/request";
import type { RequestContext } from "@warp-drive/core/types/request";
import type { Normalizer } from "discourse/data/warp-rest-model";
import { ajax, type AjaxOptions } from "discourse/lib/ajax";

const discourseRestHandler: Handler = {
  // The handler contract is generic over the content a caller expects; this
  // one always resolves to the JSON:API document the cache consumes.
  async request<T>(context: RequestContext, next: NextFn<T>) {
    const request = context.request;
    if (!request.url) {
      return next(request);
    }

    const ajaxOptions: AjaxOptions = {
      type: (request.method ?? "GET").toUpperCase(),
    };
    const body = request.options?.body;
    if (body !== undefined && body !== null) {
      ajaxOptions.data = body as AjaxOptions["data"];
    }

    const raw = await ajax(request.url, ajaxOptions);
    // Set by the builders in `discourse/data/builders`.
    const normalize = request.options?.normalize as Normalizer | undefined;
    if (normalize) {
      return normalize(raw) as T;
    }
    // No normalizer (delete, custom actions) — `{ data: null }` is the only
    // shape the cache validator accepts as a no-op.
    return { data: null } as T;
  },
};

export default discourseRestHandler;
