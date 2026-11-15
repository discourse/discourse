import {
  aliases,
  emojiReplacementRegex,
  emojis,
  replacements,
  tonableEmojis,
  translations,
} from "./emoji/data.ts";
import { IMAGE_VERSION } from "./emoji/version.ts";

/** Options for building, rendering and resolving emojis. */
export interface EmojiOptions {
  /** Turns a path into a full url. Standard emoji urls need it. */
  getURL?: (url: string) => string;
  /** The standard emoji set, such as `twitter`. Standard emoji urls need it. */
  emojiSet?: string;
  /** The base url of the standard emoji images. Defaults to `/images/emoji`. */
  emojiCDNUrl?: string | null;
  /** The custom emojis by name. Each one is a url or an object with a url. */
  customEmoji?: Record<string, string | { url: string }>;
  /** Extra emoticon translations, such as `":)"` to `"slight_smile"`. */
  customEmojiTranslation?: Record<string, string> | null;
  /** Whether `performEmojiUnescape` renders emoticons such as `:)`. */
  enableEmojiShortcuts?: boolean;
  /** Whether `performEmojiEscape` turns emoticons into emoji codes. */
  emojiShortcuts?: boolean;
  /** Whether emoji codes are also replaced inside words. */
  inlineEmoji?: boolean;
  /** The emoji names that are never rendered. */
  emojiDenyList?: string[] | null;
  /** Extra classes for the rendered image. */
  class?: string;
  /** The title of the rendered image. Defaults to the emoji name. */
  title?: string;
  /** The alt text of the rendered image. Defaults to the title. */
  alt?: string;
  /** The tab index of the rendered image. Zero adds none. */
  tabIndex?: number;
  /** Whether the rendered image has no title. */
  skipTitle?: boolean;
  /** Whether the rendered image loads lazily. */
  lazy?: boolean;
}

const extendedEmojiMap = new Map<string, { url: string; group?: string }>();

/**
 * Registers a custom emoji.
 *
 * @param code - The emoji name. It is lowercased.
 * @param url - The url of the emoji image.
 * @param group - The group the emoji is listed under.
 */
export function registerEmoji(code: string, url: string, group?: string) {
  code = code.toLowerCase();
  extendedEmojiMap.set(code, { url, group });
}

export { emojiReplacementRegex };

function textEmojiRegex(inlineEmoji?: boolean) {
  return inlineEmoji ? /:[^\s:]+(?::t\d)?:?/g : /\B:[^\s:]+(?::t\d)?:?\B/g;
}

const aliasMap = new Map<string, string>();
Object.entries(aliases).forEach(([name, list]) => {
  list.forEach((alias) => aliasMap.set(alias, name));
});

function isReplaceableInlineEmoji(
  string: string,
  index: number,
  inlineEmoji?: boolean
) {
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

/**
 * Renders the emoji codes, unicode emojis and emoticons in a text as images.
 *
 * @param string - The text to render.
 * @param opts - The emoji options.
 * @returns The rendered HTML, or `undefined` when the text is empty.
 */
export function performEmojiUnescape(
  string: string | null | undefined,
  opts: EmojiOptions
): string | undefined {
  if (!string) {
    return;
  }

  const allTranslations = Object.assign(
    {},
    translations,
    opts.customEmojiTranslation || {}
  );

  const replacementFunction = (m: string, index: number) => {
    const isEmoticon = opts.enableEmojiShortcuts && !!allTranslations[m];
    const isUnicodeEmoticon = !!replacements[m] || !!replacements[m[0]];
    let emojiVal: string;

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

/**
 * Turns the unicode emojis in a text into emoji codes, and its emoticons too
 * when `emojiShortcuts` is set.
 *
 * @param string - The text to escape.
 * @param opts - The emoji options.
 * @returns The escaped text.
 */
export function performEmojiEscape(string: string, opts: EmojiOptions): string {
  const allTranslations = Object.assign(
    {},
    translations,
    opts.customEmojiTranslation || {}
  );

  const replacementFunction = (m: string, index: number) => {
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

/**
 * Checks whether an emoji is a registered or custom one.
 *
 * @param code - The emoji name.
 * @param opts - The emoji options with the custom emojis.
 * @returns `true` when it is custom, otherwise `false` or `undefined`.
 */
export function isCustomEmoji(
  code: string,
  opts?: EmojiOptions
): boolean | undefined {
  code = code.toLowerCase();
  return extendedEmojiMap.has(code) || opts?.customEmoji?.hasOwnProperty(code);
}

/**
 * Builds the image url of an emoji.
 *
 * @param code - The emoji name, with an optional skin tone such as `:t3`.
 * @param opts - The emoji options.
 * @returns The url, or `undefined` when the emoji is unknown or the options
 *   lack what a standard emoji url needs.
 */
export function buildEmojiUrl(
  code: string,
  opts: EmojiOptions
): string | undefined {
  let url: string | undefined;
  code = String(code).toLowerCase();

  if (extendedEmojiMap.has(code)) {
    url = extendedEmojiMap.get(code)!.url;
  }

  if (opts.customEmoji?.[code]) {
    // A custom emoji is either a url or an object with a url.
    url =
      (opts.customEmoji[code] as { url?: string }).url ||
      (opts.customEmoji[code] as string);
  }

  if (!url && opts.emojiSet) {
    url = standardEmojiUrl(code, opts.emojiSet, "png", opts);
  }

  if (url) {
    url = `${url}?v=${IMAGE_VERSION}`;
  }

  return url;
}

/**
 * Builds the animated image url of a standard emoji.
 *
 * Only some standard emojis are animated, so this URL may not exist.
 *
 * @param code - The emoji name.
 * @param opts - The emoji options.
 * @returns The url, or `undefined` for a custom or unknown emoji.
 */
export function buildAnimatedEmojiUrl(
  code: string,
  opts: EmojiOptions
): string | undefined {
  code = String(code).toLowerCase();

  if (isCustomEmoji(code, opts)) {
    return;
  }

  const url = standardEmojiUrl(code, "noto_animated", "avif", opts);
  if (url) {
    return `${url}?v=${IMAGE_VERSION}`;
  }
}

function standardEmojiUrl(
  code: string,
  set: string,
  extension: string,
  opts: EmojiOptions
) {
  const noToneMatch = code.match(/([^:]+):?/);

  if (
    opts.getURL &&
    noToneMatch &&
    (emojis.has(noToneMatch[1]) || aliasMap.has(noToneMatch[1]))
  ) {
    const emojiBasePath = opts.emojiCDNUrl || "/images/emoji";
    return opts.getURL(
      `${emojiBasePath}/${set}/${code.replace(/:t/, "/")}.${extension}`
    );
  }
}

export function emojiExists(code: string): boolean {
  code = code.toLowerCase();
  return extendedEmojiMap.has(code) || emojis.has(code) || aliasMap.has(code);
}

/**
 * Resolves an emoji name or alias to the emoji's name.
 *
 * @param code - The emoji name or alias.
 * @returns The emoji name, or `undefined` when the emoji is unknown.
 */
export function normalizeEmoji(code: string): string | undefined {
  code = code.toLowerCase();
  if (extendedEmojiMap.get(code) || emojis.has(code)) {
    return code;
  }
  return aliasMap.get(code);
}

let toSearch: string[] | undefined;

/**
 * Finds the emojis whose name contains a term. Names that start with the term
 * come first.
 *
 * @param term - The text to find.
 * @param options - The search options.
 * @returns The matching emoji names.
 */
export function emojiSearch(
  term: string,
  options?: {
    /** The maximum number of results. Zero returns none. */
    maxResults?: number;
    /** The skin tone to append to the emojis that take one. 1 appends none. */
    diversity?: number;
    /** The emoji names to leave out. */
    exclude?: string[] | null;
    /** Extra search terms by emoji name. */
    searchAliases?: Record<string, string[]>;
  }
): string[] {
  const maxResults = options?.maxResults;
  const diversity = options?.diversity;
  const exclude = options?.exclude || [];
  if (maxResults === 0) {
    return [];
  }

  if (!toSearch) {
    toSearch = [...emojis.keys(), ...extendedEmojiMap.keys()].sort();
  }

  const results: string[] = [];

  function addResult(t: string) {
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
 * @param term - The emoji term to check, with or without colons or tone modifiers.
 * @returns True if the emoji is skin tonable, false otherwise.
 */
export function isSkinTonableEmoji(term: string): boolean {
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
