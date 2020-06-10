import { getURLWithCDN } from "discourse-common/lib/get-url";
import PrettyText, { buildOptions } from "pretty-text/pretty-text";
import { performEmojiUnescape, buildEmojiUrl } from "pretty-text/emoji";
import WhiteLister from "pretty-text/white-lister";
import { sanitize as textSanitize } from "pretty-text/sanitizer";
import loadScript from "discourse/lib/load-script";
import { formatUsername } from "discourse/lib/utilities";
import { Promise } from "rsvp";
import { htmlSafe } from "@ember/template";

function getOpts(opts) {
  const siteSettings = Discourse.__container__.lookup("site-settings:main"),
    site = Discourse.__container__.lookup("site:main");

  opts = _.merge(
    {
      getURL: getURLWithCDN,
      currentUser: Discourse.__container__.lookup("current-user:main"),
      censoredRegexp: site.censored_regexp,
      customEmojiTranslation: site.custom_emoji_translation,
      siteSettings,
      formatUsername
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
    return text => prettyText.cook(text);
  });
}

export function sanitize(text, options) {
  return textSanitize(text, new WhiteLister(options));
}

export function sanitizeAsync(text, options) {
  return loadMarkdownIt().then(() => {
    return createPrettyText(options).sanitize(text);
  });
}

function loadMarkdownIt() {
  if (Discourse.MarkdownItURL) {
    return loadScript(Discourse.MarkdownItURL).catch(e => {
      // eslint-disable-next-line no-console
      console.error(e);
    });
  } else {
    return Promise.resolve();
  }
}

function createPrettyText(options) {
  return new PrettyText(getOpts(options));
}

function emojiOptions() {
  if (!Discourse.SiteSettings.enable_emoji) {
    return;
  }

  return {
    getURL: url => getURLWithCDN(url),
    emojiSet: Discourse.SiteSettings.emoji_set,
    enableEmojiShortcuts: Discourse.SiteSettings.enable_emoji_shortcuts,
    inlineEmoji: Discourse.SiteSettings.enable_inline_emoji_translation
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
