import { debounce } from "@ember/runloop";
import { ATTACHMENT_CSS_CLASS } from "./engines/discourse-markdown-it";
let _cache = {};

export function lookupCachedUploadUrl(shortUrl) {
  return _cache[shortUrl] || {};
}

const MISSING = "missing";

export function lookupUncachedUploadUrls(urls, ajax) {
  return ajax("/uploads/lookup-urls", {
    method: "POST",
    data: { short_urls: urls }
  }).then(uploads => {
    uploads.forEach(upload => {
      cacheShortUploadUrl(upload.short_url, {
        url: upload.url,
        short_path: upload.short_path
      });
    });

    urls.forEach(url =>
      cacheShortUploadUrl(url, {
        url: lookupCachedUploadUrl(url).url || MISSING,
        short_path: lookupCachedUploadUrl(url).short_path || MISSING
      })
    );

    return uploads;
  });
}

export function cacheShortUploadUrl(shortUrl, value) {
  _cache[shortUrl] = value;
}

export function resetCache() {
  _cache = {};
}

function retrieveCachedUrl($upload, dataAttribute, callback) {
  const cachedUpload = lookupCachedUploadUrl($upload.data(dataAttribute));
  const url =
    dataAttribute === "orig-href" ? cachedUpload.short_path : cachedUpload.url;

  if (url) {
    $upload.removeAttr(`data-${dataAttribute}`);
    if (url !== MISSING) {
      callback(url);
    }
  }
}

function _loadCachedShortUrls($uploads) {
  $uploads.each((_idx, upload) => {
    const $upload = $(upload);
    switch (upload.tagName) {
      case "A":
        retrieveCachedUrl($upload, "orig-href", url => {
          $upload.attr("href", url);

          // Replace "|attachment" with class='attachment'
          // TODO: This is a part of the cooking process now and should be
          // removed in the future.
          const content = $upload.text().split("|");
          if (content[1] === ATTACHMENT_CSS_CLASS) {
            $upload.addClass(ATTACHMENT_CSS_CLASS);
            $upload.text(content[0]);
          }
        });

        break;
      case "IMG":
        retrieveCachedUrl($upload, "orig-src", url => {
          $upload.attr("src", url);
        });

        break;
      case "SOURCE": // video tag > source tag
        retrieveCachedUrl($upload, "orig-src", url => {
          $upload.attr("src", url);

          if (url.startsWith(`//${window.location.host}`)) {
            let hostRegex = new RegExp("//" + window.location.host, "g");
            url = url.replace(hostRegex, "");
          }
          $upload.attr("src", window.location.origin + url);

          // this is necessary, otherwise because of the src change the
          // video just doesn't bother loading!
          $upload.parent()[0].load();
        });

        break;
    }
  });
}

function _loadShortUrls($uploads, ajax) {
  const urls = $uploads.toArray().map(upload => {
    const $upload = $(upload);
    return $upload.data("orig-src") || $upload.data("orig-href");
  });

  return lookupUncachedUploadUrls(urls, ajax).then(() =>
    _loadCachedShortUrls($uploads)
  );
}

export function resolveAllShortUrls(ajax) {
  const attributes =
    "img[data-orig-src], a[data-orig-href], source[data-orig-src]";
  let $shortUploadUrls = $(attributes);

  if ($shortUploadUrls.length > 0) {
    _loadCachedShortUrls($shortUploadUrls);

    $shortUploadUrls = $(attributes);
    if ($shortUploadUrls.length > 0) {
      // this is carefully batched so we can do a leading debounce (trigger right away)
      return debounce(
        null,
        () => _loadShortUrls($shortUploadUrls, ajax),
        450,
        true
      );
    }
  }
}
