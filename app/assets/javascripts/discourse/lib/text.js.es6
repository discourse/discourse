import { default as PrettyText, buildOptions } from "pretty-text/pretty-text";
import { performEmojiUnescape, buildEmojiUrl } from "pretty-text/emoji";
import WhiteLister from "pretty-text/white-lister";
import { sanitize as textSanitize } from "pretty-text/sanitizer";
import loadScript from "discourse/lib/load-script";
import { formatUsername } from "discourse/lib/utilities";

function getOpts(opts) {
  const siteSettings = Discourse.__container__.lookup("site-settings:main"),
    site = Discourse.__container__.lookup("site:main");

  opts = _.merge(
    {
      getURL: Discourse.getURLWithCDN,
      currentUser: Discourse.__container__.lookup("current-user:main"),
      censoredWords: site.censored_words,
      siteSettings,
      formatUsername
    },
    opts
  );

  return buildOptions(opts);
}

// Use this to easily create a pretty text instance with proper options
export function cook(text, options) {
  return new Handlebars.SafeString(createPrettyText(options).cook(text));
}

// everything should eventually move to async API and this should be renamed
// cook
export function cookAsync(text, options) {
  return loadMarkdownIt().then(() => cook(text, options));
}

export function sanitize(text, options) {
  return textSanitize(text, new WhiteLister(options));
}

export function sanitizeAsync(text, options) {
  return new loadMarkdownIt().then(() => {
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
    return Ember.RSVP.Promise.resolve();
  }
}

function createPrettyText(options) {
  return new PrettyText(getOpts(options));
}

function emojiOptions() {
  const siteSettings = Discourse.__container__.lookup("site-settings:main");
  if (!siteSettings.enable_emoji) {
    return;
  }

  return { getURL: Discourse.getURLWithCDN, emojiSet: siteSettings.emoji_set };
}

export function emojiUnescape(string, options) {
  const opts = _.extend(emojiOptions(), options || {});
  return opts ? performEmojiUnescape(string, opts) : string;
}

export function emojiUrlFor(code) {
  const opts = emojiOptions();
  if (opts) {
    return buildEmojiUrl(code, opts);
  }
}
