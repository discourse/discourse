const BASE62_SHA1_REGEXP = /^[0-9A-Za-z]{1,27}$/;
const BASE62_KEYS =
  "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const HEX_SHA1_REGEXP = /^[0-9a-f]{40}$/i;
const ORIGINAL_UPLOAD_SHA1_REGEXP =
  /\/original\/\dX\/(?:[./\w-]*\/)?([0-9a-f]{40})(?:[.\w-]*)?$/i;
const UPLOAD_SHORT_URL_PREFIX = "upload://";

export function imageBase62Sha1(image) {
  const base62Sha1 = image?.dataset?.base62Sha1;

  if (base62Sha1 && BASE62_SHA1_REGEXP.test(base62Sha1)) {
    return base62Sha1;
  }

  const origSrc =
    image?.getAttribute?.("data-orig-src") || image?.dataset?.origSrc;
  if (origSrc?.startsWith(UPLOAD_SHORT_URL_PREFIX)) {
    const uploadPath = origSrc.slice(UPLOAD_SHORT_URL_PREFIX.length);
    const extensionIndex = uploadPath.indexOf(".");
    const queryIndex = uploadPath.indexOf("?");
    const fragmentIndex = uploadPath.indexOf("#");
    const endIndex = [extensionIndex, queryIndex, fragmentIndex]
      .filter((index) => index !== -1)
      .sort((first, second) => first - second)[0];
    const fallbackBase62Sha1 = uploadPath.slice(
      0,
      endIndex ?? uploadPath.length
    );

    if (fallbackBase62Sha1 && BASE62_SHA1_REGEXP.test(fallbackBase62Sha1)) {
      return fallbackBase62Sha1;
    }
  }

  return base62Sha1FromUploadUrl(image);
}

function base62Sha1FromUploadUrl(image) {
  const src = image?.getAttribute?.("src");
  if (!src) {
    return;
  }

  let pathname;
  try {
    pathname = new URL(src, window.location.origin).pathname;
  } catch {
    return;
  }

  const sha1 = pathname.match(ORIGINAL_UPLOAD_SHA1_REGEXP)?.[1];
  if (!sha1 || !HEX_SHA1_REGEXP.test(sha1)) {
    return;
  }

  return base62Encode(BigInt(`0x${sha1}`));
}

function base62Encode(number) {
  if (number === 0n) {
    return "0";
  }

  let encoded = "";
  while (number > 0n) {
    encoded = BASE62_KEYS[Number(number % 62n)] + encoded;
    number /= 62n;
  }

  return encoded;
}

export function ensureImageCaptionTarget(imageWrapper) {
  const buttonWrapper = imageWrapper.querySelector(".button-wrapper");
  if (!buttonWrapper) {
    return;
  }

  let target = buttonWrapper.querySelector(".ai-post-image-caption-editor");
  if (!target) {
    target = document.createElement("span");
    target.className = "ai-post-image-caption-editor";
    buttonWrapper.appendChild(target);
  }

  return target;
}
