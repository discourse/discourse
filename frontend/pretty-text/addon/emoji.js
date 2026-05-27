import {
  aliases,
  emojiReplacementRegex,
  emojis,
  replacements,
  tonableEmojis,
  translations,
} from "./emoji/data";
import { IMAGE_VERSION } from "./emoji/version";

const extendedEmojiMap = new Map();

export function registerEmoji(code, url, group) {
  code = code.toLowerCase();
  extendedEmojiMap.set(code, { url, group });
}

export { emojiReplacementRegex };

function textEmojiRegex(inlineEmoji) {
  return inlineEmoji ? /:[^\s:]+(?::t\d)?:?/g : /\B:[^\s:]+(?::t\d)?:?\B/g;
}

const aliasMap = new Map();
Object.entries(aliases).forEach(([name, list]) => {
  list.forEach((alias) => aliasMap.set(alias, name));
});

function isReplaceableInlineEmoji(string, index, inlineEmoji) {
  if (inlineEmoji) {
    return true;
  }

  // index depends on regex; when `inlineEmoji` is false, the regex starts
  // with a `\B` character, so there's no need to subtract from the index
  const beforeEmoji = string.slice(0, index);

  return (
    beforeEmoji.length === 0 ||
    /(?:\s|[>.,\/#!$%^&*;:{}=\-_`~()])$/.test(beforeEmoji) ||
    new RegExp(`(?:${emojiReplacementRegex})$`, "g").test(beforeEmoji)
  );
}

export function performEmojiUnescape(string, opts) {
  if (!string) {
    return;
  }

  const allTranslations = Object.assign(
    {},
    translations,
    opts.customEmojiTranslation || {}
  );

  const replacementFunction = (m, index) => {
    const isEmoticon = opts.enableEmojiShortcuts && !!allTranslations[m];
    const isUnicodeEmoticon = !!replacements[m] || !!replacements[m[0]];
    let emojiVal;

    if (isEmoticon) {
      emojiVal = allTranslations[m];
    } else if (isUnicodeEmoticon) {
      emojiVal = replacements[m] || replacements[m[0]];
    } else {
      emojiVal = m.slice(1, m.length - 1);
    }
    const hasEndingColon = m.lastIndexOf(":") === m.length - 1;
    const url = buildEmojiUrl(emojiVal, opts);
    let classes = isCustomEmoji(emojiVal, opts)
      ? "emoji emoji-custom"
      : "emoji";

    if (opts.class) {
      classes += ` ${opts.class}`;
    }

    // hides denied emojis and aliases from the emoji picker
    if (opts.emojiDenyList?.includes(emojiVal)) {
      return "";
    }

    const isReplaceable =
      (isEmoticon || hasEndingColon || isUnicodeEmoticon) &&
      isReplaceableInlineEmoji(string, index, opts.inlineEmoji);

    const title = opts.title ?? emojiVal;
    const alt = opts.alt ?? opts.title ?? emojiVal;
    const tabIndex = opts.tabIndex ? ` tabindex='${opts.tabIndex}'` : "";
    return url && isReplaceable
      ? `<img width="20" height="20" src='${url}' ${
          opts.skipTitle ? "" : `title='${title}'`
        } ${
          opts.lazy ? "loading='lazy' " : ""
        }alt='${alt}' class='${classes}'${tabIndex}>`
      : m;
  };

  return string
    .replace(new RegExp(emojiReplacementRegex, "g"), replacementFunction)
    .replace(textEmojiRegex(opts.inlineEmoji), replacementFunction);
}

export function performEmojiEscape(string, opts) {
  const allTranslations = Object.assign(
    {},
    translations,
    opts.customEmojiTranslation || {}
  );

  const replacementFunction = (m, index) => {
    if (isReplaceableInlineEmoji(string, index, opts.inlineEmoji)) {
      if (allTranslations[m]) {
        return opts.emojiShortcuts ? `:${allTranslations[m]}:` : m;
      } else if (replacements[m]) {
        return `:${replacements[m]}:`;
      } else if (replacements[m[0]]) {
        return `:${replacements[m[0]]}:`;
      }
    }

    return m;
  };

  return string
    .replace(new RegExp(emojiReplacementRegex, "g"), replacementFunction)
    .replace(textEmojiRegex(opts.inlineEmoji), replacementFunction);
}

export function isCustomEmoji(code, opts) {
  code = code.toLowerCase();
  return extendedEmojiMap.has(code) || opts?.customEmoji?.hasOwnProperty(code);
}

export function buildEmojiUrl(code, opts) {
  let url;
  code = String(code).toLowerCase();

  if (extendedEmojiMap.has(code)) {
    url = extendedEmojiMap.get(code).url;
  }

  if (opts.customEmoji?.[code]) {
    url = opts.customEmoji[code].url || opts.customEmoji[code];
  }

  const noToneMatch = code.match(/([^:]+):?/);

  let emojiBasePath = "/images/emoji";
  if (opts.emojiCDNUrl) {
    emojiBasePath = opts.emojiCDNUrl;
  }

  if (
    opts.getURL &&
    opts.emojiSet &&
    noToneMatch &&
    !url &&
    (emojis.has(noToneMatch[1]) || aliasMap.has(noToneMatch[1]))
  ) {
    url = opts.getURL(
      `${emojiBasePath}/${opts.emojiSet}/${code.replace(/:t/, "/")}.png`
    );
  }

  if (url) {
    url = `${url}?v=${IMAGE_VERSION}`;
  }

  return url;
}

export function emojiExists(code) {
  code = code.toLowerCase();
  return extendedEmojiMap.has(code) || emojis.has(code) || aliasMap.has(code);
}

export function normalizeEmoji(code) {
  code = code.toLowerCase();
  if (extendedEmojiMap.get(code) || emojis.has(code)) {
    return code;
  }
  return aliasMap.get(code);
}

let toSearch;
export function emojiSearch(term, options) {
  const maxResults = options?.maxResults;
  const diversity = options?.diversity;
  const exclude = options?.exclude || [];
  if (maxResults === 0) {
    return [];
  }

  if (!toSearch) {
    toSearch = [...emojis.keys(), ...extendedEmojiMap.keys()].sort();
  }

  const results = [];

  function addResult(t) {
    const val = aliasMap.get(t) || t;
    // don't add skin tone variations or alias of denied emoji to search results
    if (!results.includes(val) && !exclude.includes(val)) {
      if (diversity && diversity > 1 && isSkinTonableEmoji(val)) {
        results.push(`${val}:t${diversity}`);
      } else {
        results.push(val);
      }
    }
  }

  // if term matches from beginning
  for (const item of toSearch) {
    if (item.startsWith(term)) {
      addResult(item);
    }
  }

  if (options?.searchAliases) {
    for (const [key, value] of Object.entries(options.searchAliases)) {
      for (const item of value) {
        if (item.startsWith(term)) {
          addResult(key);
        }
      }
    }
  }

  for (const item of toSearch) {
    if (item.indexOf(term) > 0) {
      addResult(item);
    }
  }

  if (maxResults) {
    return results.slice(0, maxResults);
  } else {
    return results;
  }
}

/**
 * Returns true if the given emoji term is skin tonable.
 *
 * A skin tonable emoji is one that can be suffixed with a tone modifier (e.g. :t1:, :t2:, etc.)
 * to change the skin tone of the emoji.
 *
 * If the emoji already has a tone modifier, it is not considered skin tonable.
 *
 * @param {string} term The emoji term to check, with or without colons or tone modifiers.
 * @returns {boolean} True if the emoji is skin tonable, false otherwise.
 */
export function isSkinTonableEmoji(term) {
  // Check if the emoji term already has a tone modifier
  if (/:t[1-6]:?$/.test(term)) {
    return false;
  }

  // Extract the base emoji from any wrapping colons or whitespace
  const match = term.split(":").filter(Boolean)[0];
  if (match) {
    return tonableEmojis.includes(match);
  }
  return false;
}
