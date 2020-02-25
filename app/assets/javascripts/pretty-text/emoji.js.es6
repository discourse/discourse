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

export function buildReplacementsList(emojiReplacements) {
  return Object.keys(emojiReplacements)
    .sort()
    .reverse()
    .map(emoji => {
      return emoji
        .split("")
        .map(chr => {
          return (
            "\\u" +
            chr
              .charCodeAt(0)
              .toString(16)
              .padStart(4, "0")
          );
        })
        .join("");
    })
    .join("|");
}

let replacementListCache;
const unicodeRegexpCache = {};

function replacementList() {
  if (replacementListCache === undefined) {
    replacementListCache = buildReplacementsList(replacements);
  }

  return replacementListCache;
}

function unicodeRegexp(inlineEmoji) {
  if (unicodeRegexpCache[inlineEmoji] === undefined) {
    const emojiExpression = inlineEmoji
      ? "|:[^\\s:]+(?::t\\d)?:?"
      : "|\\B:[^\\s:]+(?::t\\d)?:?\\B";

    unicodeRegexpCache[inlineEmoji] = new RegExp(
      replacementList() + emojiExpression,
      "g"
    );
  }

  return unicodeRegexpCache[inlineEmoji];
}

// add all default emojis
emojis.forEach(code => (emojiHash[code] = true));

// and their aliases
const aliasHash = {};
Object.keys(aliases).forEach(name => {
  aliases[name].forEach(alias => (aliasHash[alias] = name));
});

function isReplacableInlineEmoji(string, index, inlineEmoji) {
  if (inlineEmoji) return true;

  // index depends on regex; when `inlineEmoji` is false, the regex starts
  // with a `\B` character, so there's no need to subtract from the index
  const beforeEmoji = string.slice(0, index - (inlineEmoji ? 1 : 0));

  return (
    beforeEmoji.length === 0 ||
    /(?:\s|[>.,\/#!$%^&*;:{}=\-_`~()])$/.test(beforeEmoji) ||
    new RegExp(`(?:${replacementList()})$`).test(beforeEmoji)
  );
}

export function performEmojiUnescape(string, opts) {
  if (!string) {
    return;
  }

  const inlineEmoji = opts.inlineEmoji;
  const regexp = unicodeRegexp(inlineEmoji);

  return string.replace(regexp, (m, index) => {
    const isEmoticon = opts.enableEmojiShortcuts && !!translations[m];
    const isUnicodeEmoticon = !!replacements[m];
    let emojiVal;
    if (isEmoticon) {
      emojiVal = translations[m];
    } else if (isUnicodeEmoticon) {
      emojiVal = replacements[m];
    } else {
      emojiVal = m.slice(1, m.length - 1);
    }
    const hasEndingColon = m.lastIndexOf(":") === m.length - 1;
    const url = buildEmojiUrl(emojiVal, opts);
    const classes = isCustomEmoji(emojiVal, opts)
      ? "emoji emoji-custom"
      : "emoji";

    const isReplacable =
      (isEmoticon || hasEndingColon || isUnicodeEmoticon) &&
      isReplacableInlineEmoji(string, index, inlineEmoji);

    return url && isReplacable
      ? `<img src='${url}' ${
          opts.skipTitle ? "" : `title='${emojiVal}'`
        } alt='${emojiVal}' class='${classes}'>`
      : m;
  });
}

export function performEmojiEscape(string, opts) {
  const inlineEmoji = opts.inlineEmoji;
  const regexp = unicodeRegexp(inlineEmoji);

  return string.replace(regexp, (m, index) => {
    if (isReplacableInlineEmoji(string, index, inlineEmoji)) {
      if (!!translations[m]) {
        return opts.emojiShortcuts ? `:${translations[m]}:` : m;
      } else if (!!replacements[m]) {
        return `:${replacements[m]}:`;
      }
    }

    return m;
  });
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
