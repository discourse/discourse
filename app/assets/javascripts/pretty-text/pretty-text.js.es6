import { cook, setup } from 'pretty-text/engines/discourse-markdown';
import { cook as cookIt, setup as setupIt } from 'pretty-text/engines/discourse-markdown-it';
import { sanitize } from 'pretty-text/sanitizer';
import WhiteLister from 'pretty-text/white-lister';

const _registerFns = [];
const identity = value => value;

export function registerOption(fn) {
  _registerFns.push(fn);
}

export function buildOptions(state) {
  const {
    siteSettings,
    getURL,
    lookupAvatar,
    getTopicInfo,
    topicId,
    categoryHashtagLookup,
    userId,
    getCurrentUser,
    currentUser,
    lookupAvatarByPostNumber,
    emojiUnicodeReplacer
  } = state;

  if (!siteSettings.enable_experimental_markdown_it) {
    setup();
  }

  const features = {
    'bold-italics': true,
    'auto-link': true,
    'mentions': true,
    'bbcode': true,
    'quote': true,
    'html': true,
    'category-hashtag': true,
    'onebox': true,
    'newline': !siteSettings.traditional_markdown_linebreaks
  };

  const options = {
    sanitize: true,
    getURL,
    features,
    lookupAvatar,
    getTopicInfo,
    topicId,
    categoryHashtagLookup,
    userId,
    getCurrentUser,
    currentUser,
    lookupAvatarByPostNumber,
    mentionLookup: state.mentionLookup,
    emojiUnicodeReplacer,
    allowedHrefSchemes: siteSettings.allowed_href_schemes ? siteSettings.allowed_href_schemes.split('|') : null,
    markdownIt: siteSettings.enable_experimental_markdown_it
  };

  if (siteSettings.enable_experimental_markdown_it) {
    setupIt(options, siteSettings, state);
  } else {
    // TODO deprecate this
    _registerFns.forEach(fn => fn(siteSettings, options, state));
  }

  return options;
}

export default class {
  constructor(opts) {
    this.opts = opts || {};
    this.opts.features = this.opts.features || {};
    this.opts.sanitizer = (!!this.opts.sanitize) ? (this.opts.sanitizer || sanitize) : identity;
    // We used to do a failsafe call to setup here
    // under new engine we always expect setup to be called by buildOptions.
    // setup();
  }

  cook(raw) {
    if (!raw || raw.length === 0) { return ""; }

    let result;

    if (this.opts.markdownIt) {
      result = cookIt(raw, this.opts);
    } else {
      result = cook(raw, this.opts);
    }

    return result ? result : "";
  }

  sanitize(html) {
    return this.opts.sanitizer(html, new WhiteLister(this.opts));
  }
};
