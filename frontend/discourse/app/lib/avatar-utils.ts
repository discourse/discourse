import escape from "discourse/lib/escape";
import { getURLWithCDN } from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { deepMerge } from "discourse/lib/object";
import type SiteSettingsService from "discourse/services/site-settings";

/** The named avatar sizes `translateSize` knows. */
export type AvatarSizeName =
  | "micro"
  | "tiny"
  | "small"
  | "medium"
  | "large"
  | "extra_large"
  | "huge";

/**
 * An avatar size: a name, a size in pixels, or any other string, which
 * `translateSize` passes through unchanged.
 */
export type AvatarSize = AvatarSizeName | number | string;

/** Builds a URL from a path, like `getURLWithCDN`. */
export type AvatarGetURL = (url: string) => string;

/** Options for `avatarUrl`. */
export interface AvatarUrlOptions {
  /** Builds the URL instead of `getURLWithCDN`. */
  customGetURL?: AvatarGetURL;
}

/** Options for `avatarImg`. */
export interface AvatarImgOptions {
  /** The avatar URL template, with a `{size}` placeholder. */
  avatarTemplate?: string | null;

  /** The size the image is shown at. */
  size: AvatarSize;

  /** Classes added after `avatar`. */
  extraClasses?: string | null;

  /** The image title. */
  title?: string | null;

  /** The value of the `loading` attribute. */
  loading?: string | null;

  /** The alt text. Empty by default. */
  alt?: string | null;
}

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the setting read here. Remove it once the service types its settings.
 */
interface AvatarSettings {
  avatar_sizes: string;
}

let allowedSizes: number[] | null = null;

/**
 * Converts a named avatar size to pixels.
 *
 * @param size - A size name or a size in pixels.
 * @returns The size in pixels. Unknown names are returned unchanged.
 */
export function translateSize(size: AvatarSizeName | number): number;
export function translateSize(size: AvatarSize): number | string;
export function translateSize(size: AvatarSize): number | string {
  switch (size) {
    case "micro":
      return 12;
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

/**
 * Scales a size by the device pixel ratio, rounded to 1x, 2x or 3x.
 *
 * @param size - The size in CSS pixels.
 * @returns The size in device pixels.
 */
export function getRawSize(size: number): number {
  const pixelRatio = window.devicePixelRatio || 1;
  let rawSize = 1;
  if (pixelRatio > 1.1 && pixelRatio < 2.1) {
    rawSize = 2;
  } else if (pixelRatio >= 2.1) {
    rawSize = 3;
  }
  return size * rawSize;
}

/**
 * The smallest avatar size the server generates that covers a size, so the
 * request is not redirected.
 *
 * @param size - The size in CSS pixels.
 * @returns One of the `avatar_sizes` site setting values.
 */
export function getRawAvatarSize(size: number): number {
  allowedSizes ??= (
    helperContext().siteSettings as SiteSettingsService & AvatarSettings
  )["avatar_sizes"]
    .split("|")
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

/**
 * Builds the URL of an avatar image.
 *
 * @param template - The avatar URL template, with a `{size}` placeholder.
 * @param size - The size the avatar is shown at.
 * @param options - The URL options.
 * @returns The URL, or `""` when there is no template.
 */
export function avatarUrl(
  template: string | null | undefined,
  size: AvatarSize,
  { customGetURL }: AvatarUrlOptions = {}
): string {
  if (!template) {
    return "";
  }
  // An unknown size name stays a string, and multiplying converts it to a number.
  const rawSize = getRawAvatarSize(translateSize(size) as number);
  const templatedPath = template.replace(/\{size\}/g, String(rawSize));
  return (customGetURL || getURLWithCDN)(templatedPath);
}

/**
 * Renders an avatar `<img>` tag.
 *
 * @param options - What to render.
 * @param customGetURL - Builds the image URL instead of `getURLWithCDN`.
 * @returns The HTML, or `""` when there is no avatar template.
 */
export function avatarImg(
  options: AvatarImgOptions,
  customGetURL?: AvatarGetURL
): string {
  const size = translateSize(options.size);
  const url = avatarUrl(options.avatarTemplate, size, { customGetURL });

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

  let loading = "";
  if (options.loading) {
    const escaped = escape(options.loading || "");
    loading = ` loading='${escaped}'`;
  }

  // Empty by default: an avatar almost always sits beside the name it belongs
  // to, where alt text would only repeat it. Pass `alt` where the image is the
  // sole identification of the person.
  const alt = escape(options.alt || "");

  return `<img alt='${alt}' width='${size}' height='${size}' src='${url}' class='${classes}'${title}${loading}>`;
}

/**
 * Renders a tiny avatar `<img>` tag.
 *
 * @param avatarTemplate - The avatar URL template, with a `{size}` placeholder.
 * @param options - More `avatarImg` options, which can also override the size.
 * @returns The HTML, or `""` when there is no avatar template.
 */
export function tinyAvatar(
  avatarTemplate: string | null | undefined,
  options?: Partial<AvatarImgOptions>
): string {
  return avatarImg(deepMerge({ avatarTemplate, size: "tiny" }, options));
}
