import {
  INLINE_ONEBOX_LOADING_CSS_CLASS,
  INLINE_ONEBOX_CSS_CLASS
} from "pretty-text/context/inline-onebox-css-classes";

// to match:
// abcd
// abcd[test]
// abcd[test=bob]
const WHITELIST_REGEX = /([^\[]+)(\[([^=]+)(=(.*))?\])?/;

export default class WhiteLister {
  constructor(options) {
    this._enabled = { default: true };
    this._allowedHrefSchemes = (options && options.allowedHrefSchemes) || [];
    this._allowedIframes = (options && options.allowedIframes) || [];
    this._rawFeatures = [["default", DEFAULT_LIST]];

    this._cache = null;

    if (options && options.features) {
      Object.keys(options.features).forEach(f => {
        if (options.features[f]) {
          this._enabled[f] = true;
        }
      });
    }
  }

  whiteListFeature(feature, info) {
    this._rawFeatures.push([feature, info]);
  }

  disable(feature) {
    this._enabled[feature] = false;
    this._cache = null;
  }

  enable(feature) {
    this._enabled[feature] = true;
    this._cache = null;
  }

  _buildCache() {
    const tagList = {};
    const attrList = {};
    const custom = [];

    this._rawFeatures.forEach(([name, info]) => {
      if (!this._enabled[name]) return;

      if (info.custom) {
        custom.push(info.custom);
        return;
      }

      if (typeof info === "string") {
        info = [info];
      }

      (info || []).forEach(tag => {
        const classes = tag.split(".");
        const tagWithAttr = classes.shift();

        const m = WHITELIST_REGEX.exec(tagWithAttr);
        if (m) {
          const [, tagname, , attr, , val] = m;
          tagList[tagname] = [];

          let attrs = (attrList[tagname] = attrList[tagname] || {});
          if (classes.length > 0) {
            attrs["class"] = (attrs["class"] || []).concat(classes);
          }

          if (attr) {
            let attrInfo = (attrs[attr] = attrs[attr] || []);

            if (val) {
              attrInfo.push(val);
            } else {
              attrs[attr] = ["*"];
            }
          }
        }
      });
    });

    this._cache = { custom, whiteList: { tagList, attrList } };
  }

  _ensureCache() {
    if (!this._cache) {
      this._buildCache();
    }
  }

  getWhiteList() {
    this._ensureCache();
    return this._cache.whiteList;
  }

  getCustom() {
    this._ensureCache();
    return this._cache.custom;
  }

  getAllowedHrefSchemes() {
    return this._allowedHrefSchemes;
  }

  getAllowedIframes() {
    return this._allowedIframes;
  }
}

// Only add to `default` when you always want your whitelist to occur. In other words,
// don't change this for a plugin or a feature that can be disabled
export const DEFAULT_LIST = [
  "a.attachment",
  "a.hashtag",
  "a.mention",
  "a.mention-group",
  "a.onebox",
  `a.${INLINE_ONEBOX_CSS_CLASS}`,
  `a.${INLINE_ONEBOX_LOADING_CSS_CLASS}`,
  "a[data-bbcode]",
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
  "img[alt]",
  "img[height]",
  "img[title]",
  "img[width]",
  "ins",
  "kbd",
  "li",
  "ol",
  "ol[start]",
  "p",
  "p[lang]",
  "pre",
  "s",
  "small",
  "span[lang]",
  "span.excerpt",
  "div.excerpt",
  "div.video-container",
  "span.hashtag",
  "span.mention",
  "strike",
  "strong",
  "sub",
  "sup",
  "source[src]",
  "source[data-orig-src]",
  "source[type]",
  "track",
  "track[default]",
  "track[label]",
  "track[kind]",
  "track[src]",
  "track[srclang]",
  "ul",
  "video",
  "video[controls]",
  "video[controlslist]",
  "video[crossorigin]",
  "video[height]",
  "video[poster]",
  "video[width]",
  "video[controls]",
  "video[preload]",
  "ruby",
  "ruby[lang]",
  "rb",
  "rb[lang]",
  "rp",
  "rt",
  "rt[lang]"
];
