import { emoji, aliases, translations } from 'pretty-text/emoji/data';

// bump up this number to expire all emojis
export const IMAGE_VERSION = "2";

const extendedEmoji = {};

export function registerEmoji(code, url) {
  code = code.toLowerCase();
  extendedEmoji[code] = url;
}

export function emojiList() {
  const result = emoji.slice(0);
  _.each(extendedEmoji, (v,k) => result.push(k));
  return result;
}

const emojiHash = {};

// add all default emojis
emoji.forEach(code => emojiHash[code] = true);

// and their aliases
const aliasHash = {};
Object.keys(aliases).forEach(name => {
  aliases[name].forEach(alias => aliasHash[alias] = name);
});

export function performEmojiUnescape(string, opts) {
  // this can be further improved by supporting matches of emoticons that don't begin with a colon
  if (string.indexOf(":") >= 0) {
    return string.replace(/\B:[^\s:]+:?\B/g, m => {
      const isEmoticon = !!translations[m];
      const emojiVal = isEmoticon ? translations[m] : m.slice(1, m.length - 1);
      const hasEndingColon = m.lastIndexOf(":") === m.length - 1;
      const url = buildEmojiUrl(emojiVal, opts);

      return url && (isEmoticon || hasEndingColon) ?
             `<img src='${url}' title='${emojiVal}' alt='${emojiVal}' class='emoji'>` : m;
    });
  }

  return string;
}

export function buildEmojiUrl(code, opts) {
  let url;
  code = code.toLowerCase();

  if (extendedEmoji.hasOwnProperty(code)) {
    url = extendedEmoji[code];
  }

  if (opts && opts.customEmoji && opts.customEmoji[code]) {
    url = opts.customEmoji[code];
  }

  if (!url && emojiHash.hasOwnProperty(code)) {
    url = opts.getURL(`/images/emoji/${opts.emojiSet}/${code}.png`);
  }

  if (url) {
    url = url + "?v=" + IMAGE_VERSION;
  }

  return url;
}

export function emojiExists(code) {
  code = code.toLowerCase();
  return !!(extendedEmoji.hasOwnProperty(code) || emojiHash.hasOwnProperty(code));
};

let toSearch;
export function emojiSearch(term, options) {
  const maxResults = (options && options["maxResults"]) || -1;
  if (maxResults === 0) { return []; }

  toSearch = toSearch || _.union(_.keys(emojiHash), _.keys(extendedEmoji), _.keys(aliasHash)).sort();

  const results = [];

  function addResult(t) {
    const val = aliasHash[t] || t;
    if (results.indexOf(val) === -1) {
      results.push(val);
    }
    return maxResults > 0 && results.length >= maxResults;
  }

  for (let i=0; i<toSearch.length; i++) {
    const item = toSearch[i];
    if (item.indexOf(term) === 0 && addResult(item)) {
      return results;
    }
  }

  for (let i=0; i<toSearch.length; i++) {
    const item = toSearch[i];
    if (item.indexOf(term) > 0 && addResult(item)) {
      return results;
    }
  }

  return results;
};
