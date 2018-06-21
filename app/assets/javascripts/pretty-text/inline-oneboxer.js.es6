let _cache = {};

export function applyInlineOneboxes(inline, ajax) {
  Object.keys(inline).forEach(url => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  return ajax("/inline-onebox", {
    data: { urls: Object.keys(inline) }
  }).then(result => {
    result["inline-oneboxes"].forEach(onebox => {
      _cache[onebox.url] = onebox;
      let links = inline[onebox.url] || [];
      links.forEach(link => {
        link.text(onebox.title);
      });
    });
  });
}

export function cachedInlineOnebox(url) {
  return _cache[url];
}
