import {
  INLINE_ONEBOX_LOADING_CSS_CLASS,
  INLINE_ONEBOX_CSS_CLASS
} from "pretty-text/context/inline-onebox-css-classes";

const _cache = {};

export function applyInlineOneboxes(inline, ajax) {
  Object.keys(inline).forEach(url => {
    // cache a blank locally, so we never trigger a lookup
    _cache[url] = {};
  });

  return ajax("/inline-onebox", {
    data: { urls: Object.keys(inline) }
  }).then(result => {
    result["inline-oneboxes"].forEach(onebox => {
      if (onebox.title) {
        _cache[onebox.url] = onebox;
        let links = inline[onebox.url] || [];
        links.forEach(link => {
          $(link)
            .text(onebox.title)
            .addClass(INLINE_ONEBOX_CSS_CLASS)
            .removeClass(INLINE_ONEBOX_LOADING_CSS_CLASS);
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
