let _cache = {};

export function lookupCachedUploadUrl(shortUrl) {
  return _cache[shortUrl];
}

export function lookupUncachedUploadUrls(urls, ajax) {
  return ajax("/uploads/lookup-urls", {
    method: "POST",
    data: { short_urls: urls }
  }).then(uploads => {
    uploads.forEach(upload =>
      cacheShortUploadUrl(upload.short_url, upload.url)
    );
    urls.forEach(url =>
      cacheShortUploadUrl(url, lookupCachedUploadUrl(url) || "missing")
    );
    return uploads;
  });
}

export function cacheShortUploadUrl(shortUrl, url) {
  _cache[shortUrl] = url;
}

export function resetCache() {
  _cache = {};
}

function _loadCachedShortUrls($images) {
  $images.each((idx, image) => {
    const $image = $(image);
    const url = lookupCachedUploadUrl($image.data("orig-src"));

    if (url) {
      $image.removeAttr("data-orig-src");
      if (url !== "missing") {
        $image.attr("src", url);
      }
    }
  });
}

function _loadShortUrls($images, ajax) {
  const urls = $images.toArray().map(img => $(img).data("orig-src"));
  return lookupUncachedUploadUrls(urls, ajax).then(() =>
    _loadCachedShortUrls($images)
  );
}

export function resolveAllShortUrls(ajax) {
  let $shortUploadUrls = $("img[data-orig-src]");

  if ($shortUploadUrls.length > 0) {
    _loadCachedShortUrls($shortUploadUrls);

    $shortUploadUrls = $("img[data-orig-src]");
    if ($shortUploadUrls.length > 0) {
      // this is carefully batched so we can do a leading debounce (trigger right away)
      return Ember.run.debounce(
        null,
        () => _loadShortUrls($shortUploadUrls, ajax),
        450,
        true
      );
    }
  }
}
