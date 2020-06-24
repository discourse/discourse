import { debounce } from "@ember/runloop";
let _cache = {};

export function lookupCachedUploadUrl(shortUrl) {
  return _cache[shortUrl] || {};
}

const MISSING = "missing";

export function lookupUncachedUploadUrls(urls, ajax) {
  urls = _.compact(urls);
  if (urls.length === 0) {
    return;
  }

  return ajax("/uploads/lookup-urls", {
    type: "POST",
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

function retrieveCachedUrl(upload, siteSettings, dataAttribute, callback) {
  const cachedUpload = lookupCachedUploadUrl(
    upload.getAttribute(`data-${dataAttribute}`)
  );
  const url = getAttributeBasedUrl(dataAttribute, cachedUpload, siteSettings);

  if (url) {
    upload.removeAttribute(`data-${dataAttribute}`);
    if (url !== MISSING) {
      callback(url);
    }
  }
}

function getAttributeBasedUrl(dataAttribute, cachedUpload, siteSettings) {
  if (!cachedUpload.url) {
    return;
  }

  // non-attachments always use the full URL
  if (dataAttribute !== "orig-href") {
    return cachedUpload.url;
  }

  // attachments should use the full /secure-media-uploads/ URL
  // in this case for permission checks
  if (
    siteSettings.secure_media &&
    cachedUpload.url.indexOf("secure-media-uploads") > -1
  ) {
    return cachedUpload.url;
  }

  return cachedUpload.short_path;
}

function _loadCachedShortUrls(uploadElements, siteSettings) {
  uploadElements.forEach(upload => {
    switch (upload.tagName) {
      case "A":
        retrieveCachedUrl(upload, siteSettings, "orig-href", url => {
          upload.href = url;
        });

        break;
      case "IMG":
        retrieveCachedUrl(upload, siteSettings, "orig-src", url => {
          upload.src = url;
        });

        break;
      case "SOURCE": // video/audio tag > source tag
        retrieveCachedUrl(upload, siteSettings, "orig-src", url => {
          if (url.startsWith(`//${window.location.host}`)) {
            let hostRegex = new RegExp("//" + window.location.host, "g");
            url = url.replace(hostRegex, "");
          }
          let fullUrl = window.location.origin + url;
          upload.src = fullUrl;

          // this is necessary, otherwise because of the src change the
          // video/audio just doesn't bother loading!
          upload.parentElement.load();

          // set the url and text for the <a> tag within the <video/audio> tag
          const link = upload.parentElement.querySelector("a");
          if (link) {
            link.href = fullUrl;
            link.textContent = fullUrl;
          }
        });

        break;
    }
  });
}

function _loadShortUrls(uploads, ajax, siteSettings) {
  let urls = [...uploads].map(upload => {
    return (
      upload.getAttribute("data-orig-src") ||
      upload.getAttribute("data-orig-href")
    );
  });

  return lookupUncachedUploadUrls(urls, ajax).then(() =>
    _loadCachedShortUrls(uploads, siteSettings)
  );
}

export function resolveAllShortUrls(ajax, siteSettings, scope) {
  const attributes =
    "img[data-orig-src], a[data-orig-href], source[data-orig-src]";
  let shortUploadElements = scope.querySelectorAll(attributes);

  if (shortUploadElements.length > 0) {
    _loadCachedShortUrls(shortUploadElements, siteSettings);

    shortUploadElements = scope.querySelectorAll(attributes);
    if (shortUploadElements.length > 0) {
      // this is carefully batched so we can do a leading debounce (trigger right away)
      return debounce(
        null,
        _loadShortUrls,
        shortUploadElements,
        ajax,
        siteSettings,
        450,
        true
      );
    }
  }
}
