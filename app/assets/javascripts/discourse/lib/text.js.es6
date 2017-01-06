import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';
import { performEmojiUnescape, buildEmojiUrl } from 'pretty-text/emoji';
import WhiteLister from 'pretty-text/white-lister';
import { sanitize as textSanitize } from 'pretty-text/sanitizer';

function getOpts() {
  const siteSettings = Discourse.__container__.lookup('site-settings:main');

  return buildOptions({
    getURL: Discourse.getURLWithCDN,
    currentUser: Discourse.__container__.lookup('current-user:main'),
    siteSettings
  });
}

// Use this to easily create a pretty text instance with proper options
export function cook(text) {
  return new Handlebars.SafeString(new PrettyText(getOpts()).cook(text));
}

export function sanitize(text) {
  return textSanitize(text, new WhiteLister(getOpts()));
}

function emojiOptions() {
  const siteSettings = Discourse.__container__.lookup('site-settings:main');
  if (!siteSettings.enable_emoji) { return; }

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
