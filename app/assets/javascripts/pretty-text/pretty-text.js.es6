import { cook as cookIt, setup as setupIt } from 'pretty-text/engines/discourse-markdown-it';

export function registerOption() {
  // TODO next major version deprecate this
  // if (window.console) {
  //   window.console.log("registerOption is deprecated");
  // }
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
    emojiUnicodeReplacer,
    lookupInlineOnebox,
    lookupImageUrls,
    previewing,
    linkify,
    censoredWords
  } = state;

  let features = {
    'bold-italics': true,
    'auto-link': true,
    'mentions': true,
    'bbcode': true,
    'quote': true,
    'html': true,
    'category-hashtag': true,
    'onebox': true,
    'linkify': linkify !== false,
    'newline': !siteSettings.traditional_markdown_linebreaks
  };

  if (state.features) {
    features = _.merge(features, state.features);
  }

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
    lookupInlineOnebox,
    lookupImageUrls,
    censoredWords,
    allowedHrefSchemes: siteSettings.allowed_href_schemes ? siteSettings.allowed_href_schemes.split('|') : null,
    allowedIframes: siteSettings.allowed_iframes ? siteSettings.allowed_iframes.split('|') : [],
    markdownIt: true,
    previewing
  };

  // note, this will mutate options due to the way the API is designed
  // may need a refactor
  setupIt(options, siteSettings, state);

  return options;
}

export default class {
  constructor(opts) {
    if (!opts) {
      opts = buildOptions({ siteSettings: {}});
    }
    this.opts = opts;
  }

  disableSanitizer() {
    this.opts.sanitizer = this.opts.discourse.sanitizer = ident => ident;
  }

  cook(raw) {
    if (!raw || raw.length === 0) { return ""; }

    let result;
    result = cookIt(raw, this.opts);
    return result ? result : "";
  }

  sanitize(html) {
    return this.opts.sanitizer(html).trim();
  }
};
