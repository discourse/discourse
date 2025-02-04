import xss from "xss";
import escape from "discourse/lib/escape";

// Should match any <iframe> without a src attribute
const IFRAME_REGEXP =
  /<iframe(?![^>]*\s+src\s*=)[^>]*>[\s\S]*?(<\/iframe\s*>|$)/gi;

function attr(name, value) {
  if (value) {
    return `${name}="${xss.escapeAttrValue(value)}"`;
  }

  return name;
}

export { escape };

export function hrefAllowed(href, extraHrefMatchers) {
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

function sanitizeMediaSrc(tag, attrName, value, extraHrefMatchers) {
  const srcAttrs = {
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

function testDataAttribute(forTag, name, value) {
  return Object.keys(forTag).find((k) => {
    const nameWithMatcher = `^${k.replace(/\*$/, "\\w+?")}`;
    const validValues = forTag[k];

    return (
      new RegExp(nameWithMatcher).test(name) &&
      (validValues.includes("*") ? true : validValues.includes(value))
    );
  });
}

export function sanitize(text, allowLister) {
  if (!text) {
    return "";
  }

  // Allow things like <3 and <_<
  text = text.replace(/<([^A-Za-z\/\!]|$)/g, "&lt;$1");

  const allowList = allowLister.getAllowList(),
    allowedHrefSchemes = allowLister.getAllowedHrefSchemes(),
    allowedIframes = allowLister.getAllowedIframes();
  let extraHrefMatchers = null;

  if (allowedHrefSchemes && allowedHrefSchemes.length > 0) {
    extraHrefMatchers = [
      new RegExp("^(" + allowedHrefSchemes.join("|") + ")://[\\w\\.\\-]+", "i"),
    ];
    if (allowedHrefSchemes.includes("tel")) {
      extraHrefMatchers.push(new RegExp("^tel://\\+?[\\w\\.\\-]+", "i"));
    }
  }

  let result = xss(text, {
    allowList: allowList.tagList,
    stripIgnoreTag: true,
    stripIgnoreTagBody: ["script", "table"],

    onIgnoreTagAttr(tag, name, value) {
      const forTag = allowList.attrList[tag];
      if (forTag) {
        const forAttr = forTag[name];

        if (
          (forAttr && (forAttr.includes("*") || forAttr.includes(value))) ||
          (!name.includes("data-html-") &&
            name.startsWith("data-") &&
            (forTag["data-*"] || testDataAttribute(forTag, name, value))) ||
          (tag === "a" &&
            name === "href" &&
            hrefAllowed(value, extraHrefMatchers)) ||
          (tag === "iframe" &&
            name === "src" &&
            !value.match(/\/\.+\//) &&
            allowedIframes.some((i) => {
              return value.toLowerCase().startsWith((i || "").toLowerCase());
            }))
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
