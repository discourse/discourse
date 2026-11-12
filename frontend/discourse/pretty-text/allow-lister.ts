// to match:
// abcd
// abcd[test]
// abcd[test=bob]
const ALLOWLIST_REGEX = /([^\[]+)(\[([^=]+)(=(.*))?\])?/;

/**
 * A rule that allows an attribute the allow list doesn't cover. A truthy
 * return allows the attribute.
 */
export type AllowListCustomRule = (
  tag: string,
  name: string,
  value: string
) => unknown;

/**
 * What a feature allows: one or more entries such as `a.mention` or
 * `div[data-*]`, or a custom rule.
 */
export type AllowListInfo = string | string[] | { custom: AllowListCustomRule };

/** The allowed tags and, for each tag, its allowed attribute values. */
export interface AllowList {
  /** Every allowed tag, each mapped to an empty list. */
  tagList: Record<string, string[]>;
  /** The allowed values of each attribute, by tag. `*` allows any value. */
  attrList: Record<string, Record<string, string[]>>;
}

/** The options an `AllowLister` reads. Other fields are ignored. */
export interface AllowListerOptions {
  /** The extra url schemes links may use, such as `tel`. */
  allowedHrefSchemes?: string[] | null;
  /** The url patterns iframes may load. `*` matches one path segment. */
  allowedIframes?: string[] | null;
  /** The features to enable, by name. */
  features?: Record<string, boolean>;
}

/**
 * Collects the tags and attributes that sanitized HTML may keep, grouped by
 * the feature that allows them.
 */
export default class AllowLister {
  declare _enabled: Record<string, boolean>;
  declare _allowedHrefSchemes: string[];
  declare _allowedIframes: string[];
  declare _rawFeatures: [string, AllowListInfo][];
  declare _cache: {
    custom: AllowListCustomRule[];
    allowList: AllowList;
  } | null;

  constructor(options?: AllowListerOptions | null) {
    this._enabled = { default: true };
    this._allowedHrefSchemes = (options && options.allowedHrefSchemes) || [];
    this._allowedIframes = (options && options.allowedIframes) || [];
    this._rawFeatures = [["default", DEFAULT_LIST]];

    this._cache = null;

    if (options && options.features) {
      Object.keys(options.features).forEach((f) => {
        if (options.features![f]) {
          this._enabled[f] = true;
        }
      });
    }
  }

  allowListFeature(feature: string, info: AllowListInfo) {
    this._rawFeatures.push([feature, info]);
  }

  disable(feature: string) {
    this._enabled[feature] = false;
    this._cache = null;
  }

  enable(feature: string) {
    this._enabled[feature] = true;
    this._cache = null;
  }

  getAllowList(): AllowList {
    this._ensureCache();
    return this._cache!.allowList;
  }

  getCustom(): AllowListCustomRule[] {
    this._ensureCache();
    return this._cache!.custom;
  }

  getAllowedHrefSchemes(): string[] {
    return this._allowedHrefSchemes;
  }

  getAllowedIframes(): string[] {
    return this._allowedIframes;
  }

  _buildCache() {
    const tagList: AllowList["tagList"] = {};
    const attrList: AllowList["attrList"] = {};
    const custom: AllowListCustomRule[] = [];

    this._rawFeatures.forEach(([name, info]) => {
      if (!this._enabled[name]) {
        return;
      }

      // A string or a list has no `custom` field, so it reads as undefined.
      if ((info as { custom?: AllowListCustomRule }).custom) {
        custom.push((info as { custom: AllowListCustomRule }).custom);
        return;
      }

      if (typeof info === "string") {
        info = [info];
      }

      ((info as string[]) || []).forEach((tag) => {
        const classes = tag.split(".");
        const tagWithAttr = classes.shift()!;

        const m = ALLOWLIST_REGEX.exec(tagWithAttr);
        if (m) {
          const [, tagname, , attr, , val] = m;
          tagList[tagname] = [];

          const attrs = (attrList[tagname] = attrList[tagname] || {});
          if (classes.length > 0) {
            attrs["class"] = (attrs["class"] || []).concat(classes);
          }

          if (attr) {
            const attrInfo = (attrs[attr] = attrs[attr] || []);

            if (val) {
              attrInfo.push(val);
            } else {
              attrs[attr] = ["*"];
            }
          }
        }
      });
    });

    this._cache = { custom, allowList: { tagList, attrList } };
  }

  _ensureCache() {
    if (!this._cache) {
      this._buildCache();
    }
  }
}

// Only add to `default` when you always want your allowlist to occur. In other words,
// don't change this for a plugin or a feature that can be disabled
export const DEFAULT_LIST = [
  "a.anchor",
  "a.attachment",
  "a.hashtag",
  "a.mention",
  "a.mention-group",
  "a.onebox",
  `a.inline-onebox`,
  `a.inline-onebox-loading`,
  "a[class=inline-onebox --gh-status-draft]",
  "a[class=inline-onebox --gh-status-open]",
  "a[class=inline-onebox --gh-status-approved]",
  "a[class=inline-onebox --gh-status-changes_requested]",
  "a[class=inline-onebox --gh-status-merged]",
  "a[class=inline-onebox --gh-status-closed]",
  "a[data-bbcode]",
  "a[data-word]",
  "a[name]",
  "a[rel=nofollow]",
  "a[rel=ugc]",
  "a[target=_blank]",
  "a[title]",
  "abbr[title]",
  "aside.quote",
  "aside[data-*]",
  "audio",
  "audio[controls]",
  "audio[preload]",
  "b",
  "big",
  "blockquote",
  "br",
  "code",
  "dd",
  "del",
  "div",
  "div.quote-controls",
  "div.title",
  "div[align]",
  "div[lang]",
  "div[data-*]" /* This may seem a bit much but polls does
                    it anyway and this is needed for themes,
                    special code in sanitizer handles data-*
                    nothing exists for data-theme-* and we
                    don't want to slow sanitize for this case
                  */,
  "div[dir]",
  "dl",
  "dt",
  "em",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "hr",
  "i",
  "iframe",
  "iframe[frameborder]",
  "iframe[height]",
  "iframe[marginheight]",
  "iframe[marginwidth]",
  "iframe[width]",
  "iframe[allowfullscreen]",
  "iframe[allow]",
  "img[alt]",
  "img[role]",
  "img[height]",
  "img[title]",
  "img[width]",
  "img[data-thumbnail]",
  // img[src] handled by sanitizer.js
  "ins",
  "kbd",
  "li",
  "mark",
  "ol",
  "ol[reversed]",
  "ol[start]",
  "ol[type]",
  "p",
  "p[lang]",
  "picture",
  "pre",
  "s",
  "small",
  "span[lang]",
  "span.excerpt",
  "div.excerpt",
  "div.video-container",
  "div.video-placeholder-container",
  "div.onebox-placeholder-container",
  "span.placeholder-icon video",
  "span.hashtag",
  "span.mention",
  "strike",
  "strong",
  "sub",
  "sup",
  "source[data-orig-src]",
  // source[src] and source[srcset] handled by sanitizer.js
  "source[type]",
  "track",
  "track[default]",
  "track[label]",
  "track[kind]",
  // track[src] handled by sanitizer.js
  "track[srclang]",
  "ul",
  "video",
  // video[autoplay] handled by sanitizer.js
  "video[controls]",
  "video[controlslist]",
  "video[crossorigin]",
  "video[height]",
  "video[loop]",
  "video[muted]",
  "video[playsinline]",
  "video[poster]",
  "video[preload]",
  "video[width]",
  "ruby",
  "ruby[lang]",
  "rb",
  "rb[lang]",
  "rp",
  "rt",
  "rt[lang]",
];
