import PrettyText, { buildOptions } from "pretty-text/pretty-text";
import { buildEmojiUrl, performEmojiUnescape } from "pretty-text/emoji";
import AllowLister from "pretty-text/allow-lister";
import { Promise } from "rsvp";
import Session from "discourse/models/session";
import { formatUsername } from "discourse/lib/utilities";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";
import loadScript from "discourse/lib/load-script";
import { sanitize as textSanitize } from "pretty-text/sanitizer";

function getOpts(opts) {
  let context = helperContext();

  opts = Object.assign(
    {
      getURL: getURLWithCDN,
      currentUser: context.currentUser,
      censoredRegexp: context.site.censored_regexp,
      customEmojiTranslation: context.site.custom_emoji_translation,
      siteSettings: context.siteSettings,
      formatUsername,
      watchedWordsReplace: context.site.watched_words_replace,
      watchedWordsLink: context.site.watched_words_link,
      additionalOptions: context.site.markdown_additional_options,
    },
    opts
  );

  return buildOptions(opts);
}

// Use this to easily create a pretty text instance with proper options
export function cook(text, options) {
  return htmlSafe(createPrettyText(options).cook(text));
}

// everything should eventually move to async API and this should be renamed
// cook
export function cookAsync(text, options) {
  return loadMarkdownIt().then(() => cook(text, options));
}

// Warm up pretty text with a set of options and return a function
// which can be used to cook without rebuilding prettytext every time
export function generateCookFunction(options) {
  return loadMarkdownIt().then(() => {
    const prettyText = createPrettyText(options);
    return (text) => prettyText.cook(text);
  });
}

export function generateLinkifyFunction(options) {
  return loadMarkdownIt().then(() => {
    const prettyText = createPrettyText(options);
    return prettyText.opts.engine.linkify;
  });
}

export function sanitize(text, options) {
  return textSanitize(text, new AllowLister(options));
}

export function sanitizeAsync(text, options) {
  return loadMarkdownIt().then(() => {
    return createPrettyText(options).sanitize(text);
  });
}

function loadMarkdownIt() {
  return new Promise((resolve) => {
    let markdownItURL = Session.currentProp("markdownItURL");
    if (markdownItURL) {
      loadScript(markdownItURL)
        .then(() => resolve())
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
        });
    } else {
      resolve();
    }
  });
}

function createPrettyText(options) {
  return new PrettyText(getOpts(options));
}

function emojiOptions() {
  let siteSettings = helperContext().siteSettings;
  if (!siteSettings.enable_emoji) {
    return;
  }

  return {
    getURL: (url) => getURLWithCDN(url),
    emojiSet: siteSettings.emoji_set,
    enableEmojiShortcuts: siteSettings.enable_emoji_shortcuts,
    inlineEmoji: siteSettings.enable_inline_emoji_translation,
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
        const text = element.textContent.substr(0, length - resultLength);
        result += encode(text);
        result += "&hellip;";
        resultLength += text.length;
      } else {
        result += encode(element.textContent);
        resultLength += element.textContent.length;
      }
    } else if (element.tagName === "A") {
      element.innerHTML = element.innerText;
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
