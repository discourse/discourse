import {
  emojis,
  aliases,
  searchAliases,
  translations,
  tonableEmojis,
  replacements
} from "pretty-text/emoji/data";
import { IMAGE_VERSION } from "pretty-text/emoji/version";

const extendedEmoji = {};

export function registerEmoji(code, url) {
  code = code.toLowerCase();
  extendedEmoji[code] = url;
}

export function extendedEmojiList() {
  return extendedEmoji;
}

const emojiHash = {};

const unicodeRegexp = new RegExp(
  Object.keys(replacements)
    .sort()
    .reverse()
    .join("|") + "|:[^\\s:]+(?::t\\d)?:?",
  "g"
);

// add all default emojis
emojis.forEach(code => (emojiHash[code] = true));

// and their aliases
const aliasHash = {};
Object.keys(aliases).forEach(name => {
  aliases[name].forEach(alias => (aliasHash[alias] = name));
});

export function performEmojiUnescape(string, opts) {
  if (!string) {
    return;
  }

  const inlineEmojiEnabled =
    typeof Discourse !== "undefined"
      ? Discourse.SiteSettings.enable_inline_emoji_translation
      : !!opts.inlineEmojiEnabled;

  let m;
  while ((m = unicodeRegexp.exec(string)) !== null) {
    const before = string.charAt(m.index - 1);
    const isEmoticon = !!translations[m[0]];
    const isUnicodeEmoticon = !!replacements[m[0]];
    let emojiVal;
    if (isEmoticon) {
      emojiVal = translations[m[0]];
    } else if (isUnicodeEmoticon) {
      emojiVal = replacements[m[0]];
    } else {
      emojiVal = m[0].slice(1, m[0].length - 1);
    }
    const hasEndingColon = m[0].lastIndexOf(":") === m[0].length - 1;
    const url = buildEmojiUrl(emojiVal, opts);
    const classes = isCustomEmoji(emojiVal, opts)
      ? "emoji emoji-custom"
      : "emoji";
    const isAllowed =
      (!inlineEmojiEnabled &&
        (/\s|[.,\/#!$%^&*;:{}=\-_`~()]/.test(before) || m.index === 0)) ||
      inlineEmojiEnabled;

    const replacement =
      url && (isEmoticon || hasEndingColon || isUnicodeEmoticon) && isAllowed
        ? `<img src='${url}' ${
            opts.skipTitle ? "" : `title='${emojiVal}'`
          } alt='${emojiVal}' class='${classes}'>`
        : m;

    string = string.replace(m[0], replacement);
  }

  return string;
}

export function performEmojiEscape(string, opts) {
  const inlineEmojiEnabled =
    typeof Discourse !== "undefined"
      ? Discourse.SiteSettings.enable_inline_emoji_translation
      : !!opts.inlineEmojiEnabled;

  let m;
  while ((m = unicodeRegexp.exec(string)) !== null) {
    let replacement;
    if (!!translations[m[0]]) {
      replacement = ":" + translations[m[0]] + ":";
    } else if (!!replacements[m[0]]) {
      replacement = ":" + replacements[m[0]] + ":";
    } else {
      replacement = m[0];
    }
    const before = string.charAt(m.index - 1);
    if (!/\B/.test(before)) {
      replacement = "\u200b" + replacement;
    }
    if (
      (!inlineEmojiEnabled && (/\s/.test(before) || /\./.test(before))) ||
      !!inlineEmojiEnabled
    ) {
      string = string.replace(m[0], replacement);
    }
  }

  return string;
}

export function isCustomEmoji(code, opts) {
  code = code.toLowerCase();
  if (extendedEmoji.hasOwnProperty(code)) return true;
  if (opts && opts.customEmoji && opts.customEmoji.hasOwnProperty(code))
    return true;
  return false;
}

export function buildEmojiUrl(code, opts) {
  let url;
  code = String(code).toLowerCase();
  if (extendedEmoji.hasOwnProperty(code)) {
    url = extendedEmoji[code];
  }

  if (opts && opts.customEmoji && opts.customEmoji[code]) {
    url = opts.customEmoji[code];
  }

  const noToneMatch = code.match(/([^:]+):?/);
  if (
    noToneMatch &&
    !url &&
    (emojiHash.hasOwnProperty(noToneMatch[1]) ||
      aliasHash.hasOwnProperty(noToneMatch[1]))
  ) {
    url = opts.getURL(
      `/images/emoji/${opts.emojiSet}/${code.replace(/:t/, "/")}.png`
    );
  }

  if (url) {
    url = url + "?v=" + IMAGE_VERSION;
  }

  return url;
}

export function emojiExists(code) {
  code = code.toLowerCase();
  return !!(
    extendedEmoji.hasOwnProperty(code) ||
    emojiHash.hasOwnProperty(code) ||
    aliasHash.hasOwnProperty(code)
  );
}

let toSearch;
export function emojiSearch(term, options) {
  const maxResults = (options && options["maxResults"]) || -1;
  if (maxResults === 0) {
    return [];
  }

  toSearch =
    toSearch ||
    _.union(_.keys(emojiHash), _.keys(extendedEmoji), _.keys(aliasHash)).sort();

  const results = [];

  function addResult(t) {
    const val = aliasHash[t] || t;
    if (results.indexOf(val) === -1) {
      results.push(val);
    }
  }

  // if term matches from beginning
  for (let i = 0; i < toSearch.length; i++) {
    const item = toSearch[i];
    if (item.indexOf(term) === 0) addResult(item);
  }

  if (searchAliases[term]) {
    results.push.apply(results, searchAliases[term]);
  }

  for (let i = 0; i < toSearch.length; i++) {
    const item = toSearch[i];
    if (item.indexOf(term) > 0) addResult(item);
  }

  if (maxResults === -1) {
    return results;
  } else {
    return results.slice(0, maxResults);
  }
}

export function isSkinTonableEmoji(term) {
  const match = _.compact(term.split(":"))[0];
  if (match) {
    return tonableEmojis.indexOf(match) !== -1;
  }
  return false;
}
