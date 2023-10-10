import { htmlSafe } from "@ember/template";
import AllowLister from "pretty-text/allow-lister";
import { buildEmojiUrl, performEmojiUnescape } from "pretty-text/emoji";
import PrettyText, { buildOptions } from "pretty-text/pretty-text";
import { sanitize as textSanitize } from "pretty-text/sanitizer";
import { Promise } from "rsvp";
import loadScript from "discourse/lib/load-script";
import { MentionsParser } from "discourse/lib/mentions-parser";
import { formatUsername } from "discourse/lib/utilities";
import Session from "discourse/models/session";
import deprecated from "discourse-common/lib/deprecated";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";

function getOpts(opts) {
  let context = helperContext();

  opts = Object.assign(
    {
      getURL: getURLWithCDN,
      currentUser: context.currentUser,
      censoredRegexp: context.site.censored_regexp,
      customEmojiTranslation: context.site.custom_emoji_translation,
      emojiDenyList: context.site.denied_emojis,
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

export function cook(text, options) {
  return loadMarkdownIt().then(() => {
    const cooked = createPrettyText(options).cook(text);
    return htmlSafe(cooked);
  });
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

// Warm up pretty text with a set of options and return a function
// which can be used to cook without rebuilding pretty-text every time
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

export function parseAsync(md, options = {}, env = {}) {
  return loadMarkdownIt().then(() => {
    return createPrettyText(options).parse(md, env);
  });
}

export async function parseMentions(markdown, options) {
  await loadMarkdownIt();
  const prettyText = createPrettyText(options);
  const mentionsParser = new MentionsParser(prettyText);
  return mentionsParser.parse(markdown);
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
