import AllowLister from "pretty-text/allow-lister";
import {
  emojiReplacementRegex,
  performEmojiEscape,
  performEmojiUnescape,
} from "pretty-text/emoji";
import { sanitize as sanitizeHtml } from "pretty-text/sanitizer";
import * as avatarUtils from "discourse/lib/avatar-utils";
import loadPluginFeatures from "discourse/static/markdown-it/features";
import DiscourseMarkdownIt from "discourse-markdown-it";
import { resetTranslationTree } from "discourse-markdown-it/features/emoji";
import { runtime } from "./runtime-state.js";

// Module-private helpers. These are handed to the markdown pipeline (and to
// avatarImg) as plain callbacks, so they are functions rather than class methods.
const ruby = globalThis.__Ruby;

function getURLNoCDN(url) {
  const paths = runtime.paths;
  if (!url) {
    return url;
  }
  if (url !== "/" && !/^\/[^\/]/.test(url)) {
    return url;
  }
  if (url.startsWith(`${paths.baseUri}/`) || url === paths.baseUri) {
    return url;
  }
  if (url[0] !== "/") {
    url = "/" + url;
  }
  return paths.baseUri + url;
}

function getURL(url) {
  const paths = runtime.paths;
  url = getURLNoCDN(url);
  if (paths.CDN && /^\\\/[^\\\/]/.test(url)) {
    url = paths.CDN + url;
  } else if (paths.S3CDN) {
    url = url.replace(paths.S3BaseUrl, paths.S3CDN);
  }
  return url;
}

const lookupUploadUrls = (urls) => ruby.lookup_upload_urls(urls);
const getTopicInfo = (i) => ruby.get_topic_info(i);
const hashtagLookup = (slug, cookingUserId, typesInPriorityOrder) =>
  ruby.hashtag_lookup(slug, cookingUserId, typesInPriorityOrder);
const lookupAvatar = (p) =>
  avatarUtils.avatarImg(
    { size: "tiny", avatarTemplate: ruby.avatar_template(p) },
    getURL
  );
const formatUsername = (username) => ruby.format_username(username);
const lookupPrimaryUserGroup = (username) =>
  ruby.lookup_primary_user_group(username);
const getCurrentUser = (userId) => ruby.get_current_user(userId);

let emojiUnicodeReplacer = null;

function buildEmojiUnicodeReplacer(replacements) {
  const regexp = new RegExp(emojiReplacementRegex, "g");
  return function (text) {
    regexp.lastIndex = 0;
    let m;
    while ((m = regexp.exec(text)) !== null) {
      let match = m[0];
      let replacement = replacements[match];
      if (!replacement) {
        match = match.replace(/️$/g, "");
        replacement = replacements[match];
      }
      if (!replacement) {
        continue;
      }
      replacement = ":" + replacement + ":";
      const before = text.charAt(m.index - 1);
      if (!/\B/.test(before)) {
        replacement = "​" + replacement;
      }
      text = text.replace(match, replacement);
    }
    text = text.replace(/️/g, "");
    return text;
  };
}

// The interface Ruby drives via `v8.call("__PrettyText.<method>", …)`.
export class PrettyTextRubyInterface {
  static cook(text, optInput) {
    runtime.paths = optInput.paths || {};
    runtime.avatarSizes = optInput.avatar_sizes;

    optInput.getURL = getURL;
    optInput.getCurrentUser = getCurrentUser;
    optInput.lookupAvatar = lookupAvatar;
    optInput.lookupPrimaryUserGroup = lookupPrimaryUserGroup;
    optInput.formatUsername = formatUsername;
    optInput.getTopicInfo = getTopicInfo;
    optInput.hashtagLookup = hashtagLookup;
    optInput.lookupUploadUrls = lookupUploadUrls;
    optInput.emojiUnicodeReplacer = emojiUnicodeReplacer;

    const pt =
      DiscourseMarkdownIt.withCustomFeatures(loadPluginFeatures()).withOptions(
        optInput
      );

    if (optInput.disableSanitizer) {
      pt.disableSanitizer();
    }

    return pt.cook(text);
  }

  static sanitize(html, allowListOptions) {
    return sanitizeHtml(html, new AllowLister(allowListOptions));
  }

  static avatarImg(avatarTemplate, size, paths, avatarSizes) {
    runtime.paths = paths || {};
    runtime.avatarSizes = avatarSizes;
    return avatarUtils.avatarImg({ size, avatarTemplate }, getURL);
  }

  static setUnicode(replacements) {
    emojiUnicodeReplacer = buildEmojiUnicodeReplacer(replacements);
  }

  static resetTranslations() {
    resetTranslationTree();
  }

  static performEmojiUnescape(text, options) {
    runtime.paths = options.paths || {};
    options.getURL = getURL;
    return performEmojiUnescape(text, options);
  }

  static performEmojiEscape(text, options) {
    return performEmojiEscape(text, options);
  }
}
