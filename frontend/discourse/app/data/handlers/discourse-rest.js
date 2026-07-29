import { ajax } from "discourse/lib/ajax";

const discourseRestHandler = {
  async request(context, next) {
    const request = context.request;
    if (!request.url) {
      return next(request);
    }

    const ajaxOptions = { type: (request.method ?? "GET").toUpperCase() };
    const body = request.options?.body;
    if (body !== undefined && body !== null) {
      ajaxOptions.data = body;
    }

    const raw = await ajax(request.url, ajaxOptions);
    const normalize = request.options?.normalize;
    if (normalize) {
      return normalize(raw);
    }
    // No normalizer (delete, custom actions) — `{ data: null }` is the only
    // shape the cache validator accepts as a no-op.
    return { data: null };
  },
};

export default discourseRestHandler;
