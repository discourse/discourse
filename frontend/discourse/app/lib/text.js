import AllowLister from "pretty-text/allow-lister";
import { buildEmojiUrl, performEmojiUnescape } from "pretty-text/emoji";
import { sanitize as textSanitize } from "pretty-text/sanitizer";
import deprecated from "discourse/lib/deprecated";
import { getURLWithCDN } from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

async function withEngine(name, ...args) {
  const engine = await import("discourse/static/markdown-it");
  return engine[name](...args);
}

export async function cook(text, options) {
  return await withEngine("cook", text, options);
}

// todo drop this function after migrating everything to cook()
export function cookAsync(text, options) {
  deprecated("cookAsync() is deprecated, call cook() instead", {
    since: "3.2.0.beta2",
    dropFrom: "3.2.0.beta5",
    id: "discourse.text.cook-async",
  });

  return cook(text, options);
}

// Warm up the engine with a set of options and return a function
// which can be used to cook without rebuilding the engine every time
export async function generateCookFunction(options) {
  return await withEngine("generateCookFunction", options);
}

export async function generateLinkifyFunction(options) {
  return await withEngine("generateLinkifyFunction", options);
}

// TODO: this one is special, it attempts to do something even without
// the engine loaded. Currently, this is what is forcing the xss library
// to be included on initial page load. The API/behavior also seems a bit
// different than the async version.
export function sanitize(text, options) {
  return textSanitize(text, new AllowLister(options));
}

export async function sanitizeAsync(text, options) {
  return await withEngine("sanitize", text, options);
}

export async function parseAsync(md, options = {}, env = {}) {
  return await withEngine("parse", md, options, env);
}

export async function parseMentions(markdown, options) {
  return await withEngine("parseMentions", markdown, options);
}

export function emojiOptions() {
  let siteSettings = helperContext().siteSettings;
  let context = helperContext();
  if (!siteSettings.enable_emoji) {
    return;
  }

  return {
    getURL: (url) => getURLWithCDN(url),
    emojiSet: siteSettings.emoji_set,
    enableEmojiShortcuts: siteSettings.enable_emoji_shortcuts,
    inlineEmoji: siteSettings.enable_inline_emoji_translation,
    emojiDenyList: context.site.denied_emojis,
    emojiCDNUrl: siteSettings.external_emoji_url,
  };
}

export function emojiUnescape(string, options) {
  const opts = emojiOptions();
  if (opts) {
    return performEmojiUnescape(string, Object.assign(opts, options || {}));
  } else {
    return string;
  }
}

export function emojiUrlFor(code) {
  const opts = emojiOptions();
  if (opts) {
    return buildEmojiUrl(code, opts);
  }
}

function encode(str) {
  return str.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

function traverse(element, callback) {
  if (callback(element)) {
    element.childNodes.forEach((child) => traverse(child, callback));
  }
}

export function excerpt(cooked, length) {
  let result = "";
  let resultLength = 0;

  const div = document.createElement("div");
  div.innerHTML = cooked;
  traverse(div, (element) => {
    if (resultLength >= length) {
      return;
    }

    if (element.nodeType === Node.TEXT_NODE) {
      if (resultLength + element.textContent.length > length) {
        const text = element.textContent.slice(0, length - resultLength);
        result += encode(text);
        result += "&hellip;";
        resultLength += text.length;
      } else {
        result += encode(element.textContent);
        resultLength += element.textContent.length;
      }
    } else if (element.tagName === "A") {
      result += element.outerHTML;
      resultLength += element.innerText.length;
    } else if (element.tagName === "IMG") {
      if (element.classList.contains("emoji")) {
        result += element.outerHTML;
      } else {
        result += "[image]";
        resultLength += "[image]".length;
      }
    } else {
      return true;
    }
  });

  return result;
}

export function humanizeList(listItems) {
  const items = Array.from(listItems);
  const last = items.pop();

  if (items.length === 0) {
    return last;
  } else {
    return [
      items.join(i18n("word_connector.comma")),
      i18n("word_connector.last_item"),
      last,
    ].join(" ");
  }
}

// Characters that require quoting in BBCode attribute values
// Based on the BBCode parser regex: [^\s\]]+ for unquoted values
const BBCODE_REQUIRES_QUOTES_PATTERN = /[\s\]]/;

/**
 * Serializes a value for use in a BBCode attribute.
 *
 * Automatically determines whether quotes are needed based on the value content.
 * Quotes are required when the value contains whitespace or `]` characters.
 *
 * @param {string|null|undefined} value - The attribute value to serialize
 * @param {string} name - The attribute name
 * @returns {string} The serialized attribute (e.g., ` name=value` or ` name="value"`) or empty string if value is falsy
 *
 * @example
 * serializeBBCodeAttr("12:00:00", "time") // returns ' time=12:00:00'
 * serializeBBCodeAttr("YYYY-MM-DD HH:mm", "format") // returns ' format="YYYY-MM-DD HH:mm"'
 * serializeBBCodeAttr(null, "time") // returns ''
 */
export function serializeBBCodeAttr(value, name) {
  if (!value) {
    return "";
  }

  const stringValue = String(value);
  const needsQuotes = BBCODE_REQUIRES_QUOTES_PATTERN.test(stringValue);

  return needsQuotes ? ` ${name}="${stringValue}"` : ` ${name}=${stringValue}`;
}

/**
 * Builds a BBCode attributes string from an object of key-value pairs.
 *
 * @param {Object} attrs - Object containing attribute key-value pairs
 * @param {Object} [opts] - Options
 * @param {string[]} [opts.skipAttrs] - Array of attribute names to skip
 * @returns {string} The serialized attributes string (e.g., 'name=value foo="bar baz"')
 */
export function buildBBCodeAttrs(attrs, opts = {}) {
  opts.skipAttrs = opts.skipAttrs ?? [];

  return Object.keys(attrs)
    .map((key) => {
      if (
        attrs[key] === null ||
        attrs[key] === undefined ||
        opts.skipAttrs.includes(key)
      ) {
        return null;
      }
      return serializeBBCodeAttr(attrs[key], key).trim();
    })
    .filter(Boolean)
    .join(" ");
}
