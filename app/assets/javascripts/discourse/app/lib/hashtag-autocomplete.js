import { cancel } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";
import { getHashtagTypeClasses as getHashtagTypeClassesNew } from "discourse/lib/hashtag-type-registry";
import { emojiUnescape } from "discourse/lib/text";
import {
  caretPosition,
  escapeExpression,
  inCodeBlock,
} from "discourse/lib/utilities";
import { INPUT_DELAY, isTesting } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseLater from "discourse-common/lib/later";
import { findRawTemplate } from "discourse-common/lib/raw-templates";

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

export async function hashtagTriggerRule(textarea) {
  return !(await inCodeBlock(textarea.value, caretPosition(textarea)));
}

export function hashtagAutocompleteOptions(
  contextualHashtagConfiguration,
  siteSettings,
  autocompleteOptions
) {
  return {
    template: findRawTemplate("hashtag-autocomplete"),
    key: "#",
    afterComplete: autocompleteOptions.afterComplete,
    treatAsTextarea: autocompleteOptions.treatAsTextarea,
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

        const hashtagType = getHashtagTypeClassesNew()[result.type];
        result.icon = hashtagType.generateIconHTML({
          preloaded: true,
          colors: result.colors,
          icon: result.icon,
          id: result.id,
        });
      });
      resultFunc(response.results || CANCELLED_STATUS);
    })
    .finally(() => {
      currentSearch = null;
    });
  return currentSearch;
}
