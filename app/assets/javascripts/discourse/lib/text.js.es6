import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';
import { performEmojiUnescape, buildEmojiUrl } from 'pretty-text/emoji';

// Use this to easily create a pretty text instance with proper options
export function cook(text) {
  const siteSettings = Discourse.__container__.lookup('site-settings:main');

  const opts = {
    getURL: Discourse.getURLWithCDN,
    siteSettings
  };

  return new Handlebars.SafeString(new PrettyText(buildOptions(opts)).cook(text));
}

function emojiOptions() {
  const siteSettings = Discourse.__container__.lookup('site-settings:main');
  if (!siteSettings.enable_emoji) { return; }

  return { getURL: Discourse.getURLWithCDN, emojiSet: siteSettings.emoji_set };
}

export function emojiUnescape(string) {
  const opts = emojiOptions();
  return opts ? performEmojiUnescape(string, opts) : string;
}

export function emojiUrlFor(code) {
  const opts = emojiOptions();
  if (opts) {
    return buildEmojiUrl(code, opts);
  }
}
