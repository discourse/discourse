import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';
import { performEmojiUnescape, buildEmojiUrl } from 'pretty-text/emoji';
import WhiteLister from 'pretty-text/white-lister';
import { sanitize as textSanitize } from 'pretty-text/sanitizer';
import loadScript from 'discourse/lib/load-script';

function getOpts(opts) {
  const siteSettings = Discourse.__container__.lookup('site-settings:main');

  opts = _.merge({
    getURL: Discourse.getURLWithCDN,
    currentUser: Discourse.__container__.lookup('current-user:main'),
    siteSettings
  }, opts);

  return buildOptions(opts);
}

// Use this to easily create a pretty text instance with proper options
export function cook(text, options) {
  return new Handlebars.SafeString(new PrettyText(getOpts(options)).cook(text));
}

// everything should eventually move to async API and this should be renamed
// cook
export function cookAsync(text, options) {
  if (Discourse.MarkdownItURL) {
    return loadScript(Discourse.MarkdownItURL)
      .then(()=>cook(text, options));
  } else {
    return Ember.RSVP.Promise.resolve(cook(text));
  }
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
