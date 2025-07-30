import { cancel } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY, isTesting } from "discourse/lib/environment";
import { getHashtagTypeClasses as getHashtagTypeClassesNew } from "discourse/lib/hashtag-type-registry";
import discourseLater from "discourse/lib/later";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { CANCELLED_STATUS } from "discourse/modifiers/d-autocomplete";

/**
 * Sets up a textarea using the jQuery autocomplete plugin, specifically
 * to match on the hashtag (#) character for autocompletion of categories,
 * tags, and other resource data types.
 *
 * @param {Array} contextualHashtagConfiguration - The hashtag datasource types in priority order
 *   that should be used when searching for or looking up hashtags from the server, determines
 *   the order of search results and the priority for looking up conflicting hashtags. See also
 *   Site.hashtag_configurations.
 * @param {$Element} $textarea - jQuery element to use for the autocompletion
 *   plugin to attach to, this is what will watch for the # matcher when the user is typing.
 * @param {Hash} siteSettings - The clientside site settings.
 * @param {Function} autocompleteOptions - Options to pass to the jQuery plugin. Must at least include:
 *
 *  - afterComplete - Called with the selected autocomplete option once it is selected.
 *
 *  Can also include:
 *
 *  - treatAsTextarea - Whether to anchor the autocompletion to the start of the input and
 *                      ensure the popper is always on top.
 **/
export function setupHashtagAutocomplete(
  contextualHashtagConfiguration,
  $textarea,
  siteSettings,
  autocompleteOptions = {}
) {
  $textarea.autocomplete(
    hashtagAutocompleteOptions(
      contextualHashtagConfiguration,
      siteSettings,
      autocompleteOptions
    )
  );
}

export async function hashtagTriggerRule(textarea, { inCodeBlock }) {
  return !(await inCodeBlock());
}

export function hashtagAutocompleteOptions(
  contextualHashtagConfiguration,
  siteSettings,
  autocompleteOptions
) {
  return {
    template: renderHashtagAutocomplete,
    key: "#",
    scrollElementSelector: ".hashtag-autocomplete__fadeout",
    autoSelectFirstSuggestion: true,
    transformComplete: (obj) => obj.ref,
    dataSource: (term) => {
      if (term.match(/\s/)) {
        return null;
      }
      return _searchGeneric(term, siteSettings, contextualHashtagConfiguration);
    },
    triggerRule: async (textarea, opts) =>
      await hashtagTriggerRule(textarea, opts),
    ...autocompleteOptions,
  };
}

let searchCache = {};
let searchCacheTime;
let currentSearch;

function _updateSearchCache(term, results) {
  searchCache[term] = results;
  searchCacheTime = new Date();
  return results;
}

// Note that the search term is _not_ required here, and we follow special
// logic similar to @mentions when there is no search term, to show some
// useful default categories, tags, etc.
function _searchGeneric(term, siteSettings, contextualHashtagConfiguration) {
  if (currentSearch) {
    currentSearch.abort();
    currentSearch = null;
  }
  if (new Date() - searchCacheTime > 30000) {
    searchCache = {};
  }
  const cached = searchCache[term];
  if (cached) {
    return cached;
  }

  return new Promise((resolve) => {
    let timeoutPromise = isTesting()
      ? null
      : discourseLater(() => {
          resolve(CANCELLED_STATUS);
        }, 5000);

    const debouncedSearch = (q, ctx, resultFunc) => {
      discourseDebounce(this, _searchRequest, q, ctx, resultFunc, INPUT_DELAY);
    };

    debouncedSearch(term, contextualHashtagConfiguration, (result) => {
      cancel(timeoutPromise);
      resolve(_updateSearchCache(term, result));
    });
  });
}

function _searchRequest(term, contextualHashtagConfiguration, resultFunc) {
  currentSearch = ajax("/hashtags/search.json", {
    data: { term, order: contextualHashtagConfiguration },
  });
  currentSearch
    .then((response) => {
      response.results?.forEach((result) => {
        // Convert :emoji: in the result text to HTML safely.
        result.text = htmlSafe(emojiUnescape(escapeExpression(result.text)));

        let opts = {
          preloaded: true,
          colors: result.colors,
          icon: result.icon,
          id: result.id,
        };

        if (result.style_type) {
          opts.style_type = result.style_type;
        }

        if (result.icon) {
          opts.icon = result.icon;
        }

        if (result.emoji) {
          opts.emoji = result.emoji;
        }

        const hashtagType = getHashtagTypeClassesNew()[result.type];
        result.icon = hashtagType.generateIconHTML(opts);
      });
      resultFunc(response.results || CANCELLED_STATUS);
    })
    .finally(() => {
      currentSearch = null;
    });
  return currentSearch;
}

function renderOption(option) {
  const metaText = option.secondary_text
    ? `<span class="hashtag-autocomplete__meta-text">(${escapeExpression(option.secondary_text)})</span>`
    : "";

  return `
    <li class="hashtag-autocomplete__option">
      <a class="hashtag-autocomplete__link" title="${escapeExpression(option.description)}" href>
        ${option.icon}
        <span class="hashtag-autocomplete__text">
          ${option.text}
          ${metaText}
        </span>
      </a>
    </li>
  `;
}

export default function renderHashtagAutocomplete({ options }) {
  return `
    <div class="autocomplete hashtag-autocomplete">
      <div class="hashtag-autocomplete__fadeout">
        <ul>
          ${options.map(renderOption).join("")}
        </ul>
      </div>
    </div>
  `;
}
