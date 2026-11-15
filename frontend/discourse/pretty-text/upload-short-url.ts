import { Promise } from "rsvp";
import type { ajax as discourseAjax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";

/** The full url and short path of an upload, by its short url. */
export interface UploadUrls {
  /** The full url, or `MISSING` when the upload wasn't found. */
  url?: string;
  /** The short path, or `MISSING` when the upload wasn't found. */
  short_path?: string;
}

/** An upload the server found for a short url. */
export interface UploadLookup {
  short_url: string;
  url: string;
  short_path: string;
}

/**
 * The site settings these functions read.
 *
 * TODO(typescript-pending): the site settings service doesn't type its
 * settings yet. Use its type once it does.
 */
interface ShortUrlSiteSettings {
  secure_uploads?: boolean;
}

/** The options for resolving short urls. */
interface ShortUrlOptions {
  /** Whether to replace an image that wasn't found with a placeholder. */
  removeMissing?: boolean;
}

let _cache: Record<string, UploadUrls> = {};

/**
 * Looks up the cached urls of an upload.
 *
 * @param shortUrl - The short url of the upload.
 * @returns The cached urls, or an empty object when there are none.
 */
export function lookupCachedUploadUrl(
  shortUrl: string | null | undefined
): UploadUrls {
  // A missing url reads a `null` or `undefined` key, which is never cached.
  return _cache[shortUrl as string] || {};
}

export const MISSING = "missing";

/**
 * Looks up the urls of uploads on the server and caches them. A short url the
 * server doesn't find is cached as `MISSING`.
 *
 * @param urls - The short urls to look up. Empty ones are skipped.
 * @param ajax - The function that makes the request.
 * @returns The uploads the server found, or `undefined` when there is
 *   nothing to look up.
 */
export function lookupUncachedUploadUrls(
  urls: (string | null | undefined)[],
  ajax: typeof discourseAjax
) {
  urls = urls.filter(Boolean);
  if (urls.length === 0) {
    return;
  }

  return ajax<UploadLookup[]>("/uploads/lookup-urls", {
    type: "POST",
    data: { short_urls: urls },
  }).then((uploads) => {
    uploads.forEach((upload) => {
      cacheShortUploadUrl(upload.short_url, {
        url: upload.url,
        short_path: upload.short_path,
      });
    });

    // The empty urls were filtered out.
    (urls as string[]).forEach((url) =>
      cacheShortUploadUrl(url, {
        url: lookupCachedUploadUrl(url).url || MISSING,
        short_path: lookupCachedUploadUrl(url).short_path || MISSING,
      })
    );

    return uploads;
  });
}

export function cacheShortUploadUrl(shortUrl: string, value: UploadUrls) {
  _cache[shortUrl] = value;
}

export function resetCache() {
  _cache = {};
}

function retrieveCachedUrl(
  upload: HTMLElement,
  siteSettings: ShortUrlSiteSettings,
  dataAttribute: string,
  opts: ShortUrlOptions | null | undefined,
  callback: (url: string) => void
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
      // Only images have a size. Other elements leave the canvas empty.
      canvas.width = (upload as HTMLImageElement).width;
      canvas.height = (upload as HTMLImageElement).height;

      const context = canvas.getContext("2d")!;

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
      let textSize: TextMetrics;
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

      upload.parentNode!.replaceChild(canvas, upload);
    }
  }
}

function getAttributeBasedUrl(
  dataAttribute: string,
  cachedUpload: UploadUrls,
  siteSettings: ShortUrlSiteSettings
) {
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

function _loadCachedShortUrls(
  uploadElements: NodeListOf<HTMLElement>,
  siteSettings: ShortUrlSiteSettings,
  opts: ShortUrlOptions | null | undefined
) {
  uploadElements.forEach((upload) => {
    switch (upload.tagName) {
      case "A":
        retrieveCachedUrl(upload, siteSettings, "orig-href", opts, (url) => {
          (upload as HTMLAnchorElement).href = url;
        });

        break;
      case "IMG":
        retrieveCachedUrl(upload, siteSettings, "orig-src", opts, (url) => {
          (upload as HTMLImageElement).src = url;
        });

        break;
      case "SOURCE": // video/audio tag > source tag
        retrieveCachedUrl(upload, siteSettings, "orig-src", opts, (url) => {
          if (url.startsWith(`//${window.location.host}`)) {
            const hostRegex = new RegExp("//" + window.location.host, "g");
            url = url.replace(hostRegex, "");
          }

          (upload as HTMLSourceElement).src = url;

          // set the url and text for the <a> tag within the <video/audio> tag
          const link = upload.parentElement!.querySelector("a");
          if (link) {
            link.href = url;
            link.textContent = url;
          }
        });

        break;
      case "DIV":
        retrieveCachedUrl(upload, siteSettings, "orig-src-id", opts, (url) => {
          upload.style.backgroundImage = `url('${url}')`;

          const placeholderIcon = upload.querySelector<HTMLElement>(
            ".placeholder-icon.video"
          )!;
          placeholderIcon.style.backgroundColor = "rgba(0, 0, 0, 0.3)";
        });

        break;
    }
  });
}

let queueUrls: (string | null)[] | null | undefined;
let queuePromise: Promise<unknown> | undefined;
let queueResolve: ((value?: unknown) => void) | null | undefined;

function queuePop(ajax: typeof discourseAjax) {
  // `_loadShortUrls` fills the queue before it schedules this call.
  lookupUncachedUploadUrls(queueUrls!, ajax)!.then(queueResolve!);
  queueUrls = queueResolve = null;
}

function _loadShortUrls(
  uploads: NodeListOf<HTMLElement>,
  ajax: typeof discourseAjax,
  siteSettings: ShortUrlSiteSettings,
  opts: ShortUrlOptions | null | undefined
) {
  const urls = [...uploads].map((upload) => {
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

  // Both branches above leave a pending queue promise.
  return queuePromise!.then(() => {
    _loadCachedShortUrls(uploads, siteSettings, opts);
  });
}

const SHORT_URL_ATTRIBUTES =
  "img[data-orig-src], a[data-orig-href], source[data-orig-src], div[data-orig-src-id], div[data-orig-src]";

/**
 * Replaces the short urls inside an element with the cached full urls.
 *
 * @param siteSettings - The site settings.
 * @param scope - The element whose uploads are resolved.
 * @param opts - The options for resolving short urls.
 */
export function resolveCachedShortUrls(
  siteSettings: ShortUrlSiteSettings,
  scope: ParentNode,
  opts?: ShortUrlOptions | null
) {
  const shortUploadElements =
    scope.querySelectorAll<HTMLElement>(SHORT_URL_ATTRIBUTES);

  if (shortUploadElements.length > 0) {
    _loadCachedShortUrls(shortUploadElements, siteSettings, opts);
  }
}

/**
 * Replaces the short urls inside an element with the full urls, and looks up
 * the ones that aren't cached.
 *
 * @param ajax - The function that makes the request.
 * @param siteSettings - The site settings.
 * @param scope - The element whose uploads are resolved.
 * @param opts - The options for resolving short urls.
 * @returns A promise that settles once the looked up urls are applied, or
 *   `undefined` when there is nothing to look up.
 */
export function resolveAllShortUrls(
  ajax: typeof discourseAjax,
  siteSettings: ShortUrlSiteSettings,
  scope: ParentNode,
  opts?: ShortUrlOptions | null
) {
  resolveCachedShortUrls(siteSettings, scope, opts);

  const shortUploadElements =
    scope.querySelectorAll<HTMLElement>(SHORT_URL_ATTRIBUTES);

  if (shortUploadElements.length > 0) {
    return _loadShortUrls(shortUploadElements, ajax, siteSettings, opts);
  }
}
