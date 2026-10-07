const TOO_MANY_REQUESTS = 429;

const _cache = {};

export async function applyInlineOneboxes(inline, ajax, opts) {
  opts = opts || {};

  const urls = Object.keys(inline).filter((url) => !_cache[url]);

  urls.forEach((url) => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  if (urls.length === 0) {
    return;
  }

  const batchSize = 10;
  for (let i = 0; i < urls.length; i += batchSize) {
    const batch = urls.slice(i, i + batchSize);

    try {
      const result = await ajax("/inline-onebox", {
        data: {
          urls: batch,
          category_id: opts.categoryId,
          topic_id: opts.topicId,
        },
      });
      result["inline-oneboxes"].forEach((onebox) => {
        if (onebox.title) {
          _cache[onebox.url] = onebox;

          let links = inline[onebox.url] || [];
          links.forEach((link) => {
            link.innerText = onebox.title;
            link.classList.add("inline-onebox");
            if (onebox.css_class) {
              link.classList.add(onebox.css_class);
            }
            link.classList.remove("inline-onebox-loading");
          });
        }
      });
    } catch (err) {
      const rateLimited = (err.jqXHR ?? err).status === TOO_MANY_REQUESTS;

      if (rateLimited) {
        urls.slice(i).forEach((url) => delete _cache[url]);
        return;
      }

      // eslint-disable-next-line no-console
      console.error("Inline onebox request failed", err, batch);
    }
  }
}

export function cachedInlineOnebox(url) {
  return _cache[url];
}

export function applyCachedInlineOnebox(url, onebox) {
  return (_cache[url] = onebox);
}

export function deleteCachedInlineOnebox(url) {
  return delete _cache[url];
}
