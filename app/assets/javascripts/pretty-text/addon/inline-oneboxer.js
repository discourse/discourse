const _cache = {};

export function applyInlineOneboxes(inline, ajax, opts) {
  opts = opts || {};

  Object.keys(inline).forEach(url => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  return ajax("/inline-onebox", {
    data: {
      urls: Object.keys(inline),
      category_id: opts.categoryId,
      topic_id: opts.topicId
    }
  }).then(result => {
    result["inline-oneboxes"].forEach(onebox => {
      if (onebox.title) {
        _cache[onebox.url] = onebox;
        let links = inline[onebox.url] || [];
        links.forEach(link => {
          $(link)
            .text(onebox.title)
            .addClass("inline-onebox")
            .removeClass("inline-onebox-loading");
        });
      }
    });
  });
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
