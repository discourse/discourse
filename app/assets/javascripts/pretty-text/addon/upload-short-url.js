import { Promise } from "rsvp";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";

let _cache = {};

export function lookupCachedUploadUrl(shortUrl) {
  return _cache[shortUrl] || {};
}

const MISSING = "missing";

export function lookupUncachedUploadUrls(urls, ajax) {
  urls = urls.filter(Boolean);
  if (urls.length === 0) {
    return;
  }

  return ajax("/uploads/lookup-urls", {
    type: "POST",
    data: { short_urls: urls },
  }).then((uploads) => {
    uploads.forEach((upload) => {
      cacheShortUploadUrl(upload.short_url, {
        url: upload.url,
        short_path: upload.short_path,
      });
    });

    urls.forEach((url) =>
      cacheShortUploadUrl(url, {
        url: lookupCachedUploadUrl(url).url || MISSING,
        short_path: lookupCachedUploadUrl(url).short_path || MISSING,
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

function retrieveCachedUrl(
  upload,
  siteSettings,
  dataAttribute,
  opts,
  callback
) {
  const cachedUpload = lookupCachedUploadUrl(
    upload.getAttribute(`data-${dataAttribute}`)
  );
  const url = getAttributeBasedUrl(dataAttribute, cachedUpload, siteSettings);

  if (url) {
    upload.removeAttribute(`data-${dataAttribute}`);
    if (url !== MISSING) {
      callback(url);
    } else if (opts && opts.removeMissing) {
      const style = getComputedStyle(document.body);
      const canvas = document.createElement("canvas");
      canvas.width = upload.width;
      canvas.height = upload.height;

      const context = canvas.getContext("2d");

      // Draw background
      context.fillStyle = getComputedStyle(document.body).backgroundColor;
      context.strokeRect(0, 0, canvas.width, canvas.height);

      // Draw border
      context.lineWidth = 2;
      context.strokeStyle = getComputedStyle(document.body).color;
      context.strokeRect(0, 0, canvas.width, canvas.height);

      let fontSize = 25;
      const text = i18n("image_removed");

      // Fill text size to fit the canvas
      let textSize;
      do {
        --fontSize;
        context.font = `${fontSize}px ${style.fontFamily}`;
        textSize = context.measureText(text);
      } while (textSize.width > canvas.width);

      context.fillStyle = getComputedStyle(document.body).color;
      context.fillText(
        text,
        (canvas.width - textSize.width) / 2,
        (canvas.height + fontSize) / 2
      );

      upload.parentNode.replaceChild(canvas, upload);
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

  // attachments should use the full /secure-media-uploads/ or
  // /secure-uploads/ URL in this case for permission checks
  if (
    siteSettings.secure_uploads &&
    (cachedUpload.url.includes("secure-media-uploads") ||
      cachedUpload.url.includes("secure-uploads"))
  ) {
    return cachedUpload.url;
  }

  return cachedUpload.short_path;
}

function _loadCachedShortUrls(uploadElements, siteSettings, opts) {
  uploadElements.forEach((upload) => {
    switch (upload.tagName) {
      case "A":
        retrieveCachedUrl(upload, siteSettings, "orig-href", opts, (url) => {
          upload.href = url;
        });

        break;
      case "IMG":
        retrieveCachedUrl(upload, siteSettings, "orig-src", opts, (url) => {
          upload.src = url;
        });

        break;
      case "SOURCE": // video/audio tag > source tag
        retrieveCachedUrl(upload, siteSettings, "orig-src", opts, (url) => {
          if (url.startsWith(`//${window.location.host}`)) {
            let hostRegex = new RegExp("//" + window.location.host, "g");
            url = url.replace(hostRegex, "");
          }

          upload.src = url;

          // set the url and text for the <a> tag within the <video/audio> tag
          const link = upload.parentElement.querySelector("a");
          if (link) {
            link.href = url;
            link.textContent = url;
          }
        });

        break;
      case "DIV":
        if (siteSettings.enable_diffhtml_preview === true) {
          retrieveCachedUrl(upload, siteSettings, "orig-src", opts, (url) => {
            const videoHTML = `
              <video width="100%" height="100%" preload="metadata" controls style="">
                <source src="${url}">
              </video>`;
            upload.insertAdjacentHTML("beforeend", videoHTML);
            upload.classList.add("video-container");
          });
        } else {
          retrieveCachedUrl(
            upload,
            siteSettings,
            "orig-src-id",
            opts,
            (url) => {
              upload.style.backgroundImage = `url('${url}')`;

              const placeholderIcon = upload.querySelector(
                ".placeholder-icon.video"
              );
              placeholderIcon.style.backgroundColor = "rgba(0, 0, 0, 0.3)";
            }
          );
        }
        break;
    }
  });
}

let queueUrls;
let queuePromise;
let queueResolve;

function queuePop(ajax) {
  lookupUncachedUploadUrls(queueUrls, ajax).then(queueResolve);
  queueUrls = queueResolve = null;
}

function _loadShortUrls(uploads, ajax, siteSettings, opts) {
  let urls = [...uploads].map((upload) => {
    return (
      upload.getAttribute("data-orig-src") ||
      upload.getAttribute("data-orig-href") ||
      upload.getAttribute("data-orig-src-id") ||
      upload.getAttribute("data-orig-src")
    );
  });

  if (!queueUrls) {
    queueUrls = [...urls];
    queuePromise = new Promise((resolve) => {
      queueResolve = resolve;
    });

    discourseDebounce(null, queuePop, ajax, 450);
  } else {
    queueUrls.push(...urls);
  }

  return queuePromise.then(() => {
    _loadCachedShortUrls(uploads, siteSettings, opts);
  });
}

const SHORT_URL_ATTRIBUTES =
  "img[data-orig-src], a[data-orig-href], source[data-orig-src], div[data-orig-src-id], div[data-orig-src]";

export function resolveCachedShortUrls(siteSettings, scope, opts) {
  const shortUploadElements = scope.querySelectorAll(SHORT_URL_ATTRIBUTES);

  if (shortUploadElements.length > 0) {
    _loadCachedShortUrls(shortUploadElements, siteSettings, opts);
  }
}

export function resolveAllShortUrls(ajax, siteSettings, scope, opts) {
  resolveCachedShortUrls(siteSettings, scope, opts);

  const shortUploadElements = scope.querySelectorAll(SHORT_URL_ATTRIBUTES);

  if (shortUploadElements.length > 0) {
    return _loadShortUrls(shortUploadElements, ajax, siteSettings, opts);
  }
}
