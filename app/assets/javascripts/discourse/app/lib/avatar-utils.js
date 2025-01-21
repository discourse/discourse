import escape from "discourse/lib/escape";
import { getURLWithCDN } from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { deepMerge } from "discourse/lib/object";

let allowedSizes = null;

export function translateSize(size) {
  switch (size) {
    case "tiny":
      return 24;
    case "small":
      return 24;
    case "medium":
      return 48;
    case "large":
      return 48;
    case "extra_large":
      return 96;
    case "huge":
      return 144;
  }
  return size;
}

export function getRawSize(size) {
  const pixelRatio = window.devicePixelRatio || 1;
  let rawSize = 1;
  if (pixelRatio > 1.1 && pixelRatio < 2.1) {
    rawSize = 2;
  } else if (pixelRatio >= 2.1) {
    rawSize = 3;
  }
  return size * rawSize;
}

export function getRawAvatarSize(size) {
  allowedSizes ??= helperContext()
    .siteSettings["avatar_sizes"].split("|")
    .map((s) => parseInt(s, 10))
    .sort((a, b) => a - b);

  size = getRawSize(size);

  for (let i = 0; i < allowedSizes.length; i++) {
    if (allowedSizes[i] >= size) {
      return allowedSizes[i];
    }
  }

  return allowedSizes[allowedSizes.length - 1];
}

export function avatarUrl(template, size, { customGetURL } = {}) {
  if (!template) {
    return "";
  }
  const rawSize = getRawAvatarSize(translateSize(size));
  const templatedPath = template.replace(/\{size\}/g, rawSize);
  return (customGetURL || getURLWithCDN)(templatedPath);
}

export function avatarImg(options, customGetURL) {
  const size = translateSize(options.size);
  let url = avatarUrl(options.avatarTemplate, size, { customGetURL });

  // We won't render an invalid url
  if (!url) {
    return "";
  }

  const classes =
    "avatar" + (options.extraClasses ? " " + options.extraClasses : "");

  let title = "";
  if (options.title) {
    const escaped = escape(options.title || "");
    title = ` title='${escaped}'`;
  }

  return `<img loading='lazy' alt='' width='${size}' height='${size}' src='${url}' class='${classes}'${title}>`;
}

export function tinyAvatar(avatarTemplate, options) {
  return avatarImg(deepMerge({ avatarTemplate, size: "tiny" }, options));
}
