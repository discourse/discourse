import xss from "xss";
import escape from "discourse/lib/escape";
import type AllowLister from "./allow-lister.ts";

/**
 * The xss default export also carries the module's named helpers, which its
 * typings leave out.
 */
type XssWithHelpers = typeof xss & {
  escapeAttrValue(value: string): string;
};

// Should match any <iframe> without a src attribute
const IFRAME_REGEXP =
  /<iframe(?![^>]*\s+src\s*=)[^>]*>[\s\S]*?(<\/iframe\s*>|$)/gi;

function attr(name: string, value?: string | null) {
  if (value) {
    return `${name}="${(xss as XssWithHelpers).escapeAttrValue(value)}"`;
  }

  return name;
}

export { escape };

/**
 * Checks whether a link url is safe to keep.
 *
 * Absolute, relative, anchor and `mailto:` urls are allowed, as are urls that
 * match one of the extra matchers.
 *
 * @param href - The url to check.
 * @param extraHrefMatchers - Extra patterns of allowed urls.
 * @returns The url with its single quotes escaped, or `undefined` when it
 *   isn't allowed.
 */
export function hrefAllowed(
  href: string,
  extraHrefMatchers?: RegExp[] | null
): string | undefined {
  // escape single quotes
  href = href.replace(/'/g, "%27");

  // absolute urls
  if (/^(https?:)?\/\/[\w\.\-]+/i.test(href)) {
    return href;
  }
  // relative urls
  if (/^\/[\w\.\-]+/i.test(href)) {
    return href;
  }
  // anchors
  if (/^#[\w\.\-]+/i.test(href)) {
    return href;
  }
  // mailtos
  if (/^mailto:[\w\.\-@]+/i.test(href)) {
    return href;
  }

  if (extraHrefMatchers && extraHrefMatchers.length > 0) {
    for (let i = 0; i < extraHrefMatchers.length; i++) {
      if (extraHrefMatchers[i].test(href)) {
        return href;
      }
    }
  }
}

function sanitizeMediaSrc(
  tag: string,
  attrName: string,
  value: string,
  extraHrefMatchers: RegExp[] | null
) {
  const srcAttrs: Record<string, string[]> = {
    img: ["src"],
    source: ["src", "srcset"],
    track: ["src"],
  };

  if (!srcAttrs[tag]?.includes(attrName)) {
    return;
  }

  if (value.startsWith("data:image")) {
    return attr(attrName, value);
  }

  if (attrName === "srcset") {
    const srcset = value.split(",").map((v) => v.split(" ", 2));
    const sanitizedValue = srcset
      .map((src) => {
        const allowedSrc = hrefAllowed(src[0], extraHrefMatchers);
        if (allowedSrc) {
          return src[1] ? `${allowedSrc} ${src[1]}` : allowedSrc;
        }
      })
      .join(",");
    return attr(attrName, sanitizedValue);
  } else {
    const returnVal = hrefAllowed(value, extraHrefMatchers);
    return attr(attrName, returnVal);
  }
}

function testDataAttribute(
  forTag: Record<string, string[]>,
  name: string,
  value: string
) {
  return Object.keys(forTag).find((k) => {
    const nameWithMatcher = `^${k.replace(/\*$/, "\\w+?")}`;
    const validValues = forTag[k];

    return (
      new RegExp(nameWithMatcher).test(name) &&
      (validValues.includes("*") ? true : validValues.includes(value))
    );
  });
}

/**
 * Checks whether a tag's allow list rules allow an attribute value.
 *
 * `data-*` attributes are allowed by a `data-*` rule or a matching wildcard
 * rule, except for `data-html-*` ones.
 *
 * @param forTag - The allowed values of each attribute of the tag.
 * @param name - The attribute name.
 * @param value - The attribute value.
 * @returns Whether the attribute is allowed.
 */
export function isAllowListedAttr(
  forTag: Record<string, string[]>,
  name: string,
  value: string
): boolean {
  const forAttr = forTag[name];

  return !!(
    (forAttr && (forAttr.includes("*") || forAttr.includes(value))) ||
    (!name.includes("data-html-") &&
      name.startsWith("data-") &&
      (forTag["data-*"] || testDataAttribute(forTag, name, value)))
  );
}

/**
 * Removes the tags and attributes an allow list doesn't allow from HTML.
 *
 * @param text - The HTML to sanitize.
 * @param allowLister - The allow lister with the allowed tags and attributes.
 * @returns The sanitized HTML, or an empty string when there is no HTML.
 */
export function sanitize(
  text: string | null | undefined,
  allowLister: AllowLister
): string {
  if (!text) {
    return "";
  }

  // Allow things like <3 and <_<
  text = text.replace(/<([^A-Za-z\/\!]|$)/g, "&lt;$1");

  const allowList = allowLister.getAllowList(),
    allowedHrefSchemes = allowLister.getAllowedHrefSchemes(),
    allowedIframes = allowLister.getAllowedIframes();
  let extraHrefMatchers: RegExp[] | null = null;

  if (allowedHrefSchemes && allowedHrefSchemes.length > 0) {
    extraHrefMatchers = [
      new RegExp("^(" + allowedHrefSchemes.join("|") + ")://[\\w\\.\\-]+", "i"),
    ];
    if (allowedHrefSchemes.includes("tel")) {
      extraHrefMatchers.push(new RegExp("^tel://\\+?[\\w\\.\\-]+", "i"));
    }
  }

  const result = xss(text, {
    allowList: allowList.tagList,
    stripIgnoreTag: true,
    stripIgnoreTagBody: ["script", "table"],

    onIgnoreTagAttr(tag, name, value) {
      const forTag = allowList.attrList[tag];
      if (forTag) {
        if (
          isAllowListedAttr(forTag, name, value) ||
          (tag === "a" &&
            name === "href" &&
            hrefAllowed(value, extraHrefMatchers)) ||
          (tag === "iframe" &&
            name === "src" &&
            (() => {
              let decoded: string;
              try {
                decoded = decodeURIComponent(value);
              } catch {
                return false;
              }
              const iframeUrls = [decoded];
              iframeUrls.push(value);
              return (
                !decoded.match(/\/\.+(?:[\/\\?#]|$)/) &&
                allowedIframes.some((i) => {
                  const regex = i
                    // escape regex, keeping *
                    .replace(/[.+?^${}()|[\]\\]/g, "\\$&")
                    .replace(/\*/g, "[^/?#\\\\]+");
                  const allowedIframe = new RegExp(`^${regex}.*$`, "i");
                  return iframeUrls.every((iframeUrl) =>
                    allowedIframe.test(iframeUrl)
                  );
                })
              );
            })())
        ) {
          return attr(name, value);
        }

        const sanitizedMediaSrc = sanitizeMediaSrc(
          tag,
          name,
          value,
          extraHrefMatchers
        );
        if (sanitizedMediaSrc) {
          return sanitizedMediaSrc;
        }

        if (tag === "iframe" && name === "src") {
          // This iframe is not allowed
          return "";
        }

        if (tag === "video" && name === "autoplay") {
          // This might give us duplicate 'muted' attributes
          // but they will be deduped by later processing
          return "autoplay muted";
        }

        // Heading ids must begin with `heading--`
        if (
          ["h1", "h2", "h3", "h4", "h5", "h6"].includes(tag) &&
          value.match(/^heading\-\-[a-zA-Z0-9\-\_]+$/)
        ) {
          return attr(name, value);
        }

        const custom = allowLister.getCustom();
        for (let i = 0; i < custom.length; i++) {
          const fn = custom[i];
          if (fn(tag, name, value)) {
            return attr(name, value);
          }
        }
      }
    },
  });

  return result
    .replace(/\[removed\]/g, "")
    .replace(IFRAME_REGEXP, "")
    .replace(/&(?![#\w]+;)/g, "&amp;")
    .replace(/&#39;/g, "'")
    .replace(/ \/>/g, ">");
}
