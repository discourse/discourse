import { emojiSearch, isSkinTonableEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import EmojiAutocompleteResults from "discourse/components/emoji-autocomplete-results";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import loadEmojiSearchAliases from "discourse/lib/load-emoji-search-aliases";
import { emojiUrlFor } from "discourse/lib/text";
import userSearch, { validateSearchResult } from "discourse/lib/user-search";
import {
  destroyUserStatuses,
  initUserStatusHtml,
  renderUserStatusHtml,
} from "discourse/lib/user-status-on-autocomplete";
import {
  EMOJI_ALLOWED_PRECEDING_CHARS_REGEXP,
  SKIP,
} from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";

const EMOJI_TERM_REGEXP = new RegExp(
  `(?:^|${EMOJI_ALLOWED_PRECEDING_CHARS_REGEXP.source})(:(?!:).?[\\w-]*:?(?!:)(?:t\\d?)?:?)$`,
  "i"
);

// typed emoticons like `:-p` or `:)` are not emoji searches
const EMOTICON_REGEXP = /[^-{}[\]()*_<>\\/].*[^-{}[\]()*_<>\\/]/;

function emojiCodes(
  term,
  { site, siteSettings, emojiStore, context, minLength, ignoreEmoticons }
) {
  const full = `:${term}`;
  term = term.toLowerCase();

  if (
    term.length < Math.max(siteSettings.emoji_autocomplete_min_chars, minLength)
  ) {
    return SKIP;
  }

  if (ignoreEmoticons && !EMOTICON_REGEXP.test(term)) {
    return SKIP;
  }

  const denied = site.denied_emojis || [];

  if (term === "") {
    const favorites = emojiStore
      .favoritesForContext(context)
      .filter((code) => !denied.includes(code));

    return favorites.length
      ? favorites.slice(0, 5)
      : ["slight_smile", "smile", "wink", "sunny", "blush"];
  }

  // only works for emojis starting with `:`, e.g. `:-)`
  const allTranslations = {
    ...translations,
    ...(site.custom_emoji_translation || {}),
  };
  if (allTranslations[full]) {
    return [allTranslations[full]];
  }

  const match = term.match(/^:?(.*?):t([2-6])?$/);
  if (match) {
    const [, name, scale] = match;

    if (isSkinTonableEmoji(name) && !denied.includes(name)) {
      return scale
        ? [`${name}:t${scale}`]
        : [2, 3, 4, 5, 6].map((x) => `${name}:t${x}`);
    }
  }

  return loadEmojiSearchAliases().then((searchAliases) =>
    emojiSearch(term, {
      maxResults: 5,
      diversity: emojiStore.diversity,
      exclude: denied,
      searchAliases,
    })
  );
}

/**
 * Emoji autocomplete options shared by composer editors. The host decides
 * what picking "more…" does and adds editor-specific options on top.
 *
 * @param {Object} opts
 * @param {Object} opts.site
 * @param {Object} opts.siteSettings
 * @param {Object} opts.emojiStore
 * @param {string} opts.context emoji store context for favorites and usage
 * @param {(term: string) => void | Promise<void>} opts.openPicker
 * @param {number} [opts.minLength=0] minimum term length on top of the site setting
 * @param {boolean} [opts.ignoreEmoticons=false] skip terms that look like typed emoticons
 * @returns {Object} autocomplete options
 */
export function emojiAutocompleteOptions({
  site,
  siteSettings,
  emojiStore,
  context,
  openPicker,
  minLength = 0,
  ignoreEmoticons = false,
}) {
  return {
    component: EmojiAutocompleteResults,
    key: EmojiAutocompleteResults.TRIGGER_KEY,

    onKeyUp: (text, caretPosition) => {
      const match = EMOJI_TERM_REGEXP.exec(text.substring(0, caretPosition));
      if (match?.[1]) {
        return [match[1]];
      }
    },

    transformComplete: async (result) => {
      if (result.code) {
        emojiStore.trackEmojiForContext(result.code, context);
        return `${result.code}:`;
      }

      await openPicker(result.term);
      return "";
    },

    dataSource: async (term) => {
      const codes = await emojiCodes(term, {
        site,
        siteSettings,
        emojiStore,
        context,
        minLength,
        ignoreEmoticons,
      });

      if (codes === SKIP || !codes.length) {
        return [];
      }

      return [
        ...codes.map((code) => ({ code, src: emojiUrlFor(code) })),
        { label: i18n("composer.more_emoji"), term },
      ];
    },
  };
}

/**
 * Mention autocomplete options shared by composer editors.
 *
 * @param {Object} opts
 * @param {import("@ember/owner").default} opts.owner
 * @param {() => Object} [opts.searchOptions] extra `userSearch` options, read per search
 * @param {(users: Object[]) => void} [opts.decorateUsers] adjusts results before rendering
 * @param {(result: Object) => void} [opts.onSelect] called with the picked result
 * @returns {Object} autocomplete options
 */
export function mentionAutocompleteOptions({
  owner,
  searchOptions = () => ({}),
  decorateUsers,
  onSelect,
}) {
  return {
    component: UserAutocompleteResults,
    key: UserAutocompleteResults.TRIGGER_KEY,

    dataSource: async (term) => {
      destroyUserStatuses();

      const result = await userSearch({
        term,
        includeGroups: true,
        ...searchOptions(),
      });

      if (result?.users?.length) {
        decorateUsers?.(result.users);
        initUserStatusHtml(owner, result.users);
      }

      return result;
    },

    onRender: (options) => renderUserStatusHtml(options),

    transformComplete: (result) => {
      onSelect?.(result);
      validateSearchResult(result);
      return result.username || result.name;
    },

    onClose: destroyUserStatuses,
  };
}
