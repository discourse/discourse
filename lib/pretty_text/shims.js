__PrettyText = require('pretty-text/pretty-text').default;
__buildOptions = require('pretty-text/pretty-text').buildOptions;
__performEmojiUnescape = require('pretty-text/emoji').performEmojiUnescape;

__utils = require('discourse/lib/utilities');
__setUnicode = require('pretty-text/engines/discourse-markdown/emoji').setUnicodeReplacements;

__paths = {};

function __getURLNoCDN(url) {
  if (!url) return url;

  // if it's a non relative URL, return it.
  if (url !== '/' && !/^\/[^\/]/.test(url)) { return url; }

  if (url.indexOf(__paths.baseUri) !== -1) { return url; }
  if (url[0] !== "/") url = "/" + url;

  return __paths.baseUri + url;
}

function __getURL(url) {
  url = __getURLNoCDN(url);
  // only relative urls
  if (__paths.CDN && /^\\\/[^\\\/]/.test(url)) {
    url = __paths.CDN + url;
  } else if (__paths.S3CDN) {
    url = url.replace(__paths.S3BaseUrl, __paths.S3CDN);
  }
  return url;
}

function __getTopicInfo(i) {
  return __helpers.get_topic_info(i);
}

function __categoryLookup(c) {
  return __helpers.category_tag_hashtag_lookup(c);
}

function __mentionLookup(u) {
  return __helpers.mention_lookup(u);
}

function __lookupAvatar(p) {
  return __utils.avatarImg({size: "tiny", avatarTemplate: __helpers.avatar_template(p) }, __getURL);
}

I18n = {
  t: function(a,b) { return __helpers.t(a,b); }
};
