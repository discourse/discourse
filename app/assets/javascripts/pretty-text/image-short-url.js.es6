let _cache = {};

export function lookupCachedUploadUrl(shortUrl) {
  return _cache[shortUrl];
}

export function lookupUncachedUploadUrls(urls, ajax) {
  return ajax('/uploads/lookup-urls', { method: 'POST', data: { short_urls: urls } })
    .then(uploads => {
      uploads.forEach(upload => _cache[upload.short_url] = upload.url);
      urls.forEach(url => _cache[url] = _cache[url] || "missing");
      return uploads;
    });
}

export function cacheShortUploadUrl(shortUrl, url) {
  _cache[shortUrl] = url;
}
