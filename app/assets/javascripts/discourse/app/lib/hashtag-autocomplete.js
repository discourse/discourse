import { cancel } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import HashtagAutocompleteResults from "discourse/components/hashtag-autocomplete-results";
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
 * @param {Function} autocompleteOptions - Options to pass to the jQuery plugin. Must at least include:
 *
 *  - afterComplete - Called with the selected autocomplete option once it is selected.
 *
 *  Can also include:
 *
 *  - treatAsTextarea - Whether to anchor the autocompletion to the start of the input and
 *                      ensure the popper is always on top.
 *
 * Note: This uses either the template-based approach or the component-based approach
 * depending on the capabilities of the DAutocomplete modifier in use.
 **/
/**
 * Sets up hashtag autocomplete for a textarea
 *
 * @param {Array} contextualHashtagConfiguration - The hashtag datasource types in priority order
 * @param {$Element} $textarea - jQuery element for the textarea
 * @param {Object} autocompleteOptions - Additional options
 * @param {boolean} [autocompleteOptions.useComponent=true] - Whether to use component-based approach
 */
export function setupHashtagAutocomplete(
  contextualHashtagConfiguration,
  $textarea,
  autocompleteOptions = {}
) {
  $textarea.autocomplete(
    hashtagAutocompleteOptions(
      contextualHashtagConfiguration,
      autocompleteOptions
    )
  );
}

export async function hashtagTriggerRule({ inCodeBlock }) {
  return !(await inCodeBlock());
}

/**
 * Returns hashtag autocomplete options for the DAutocomplete modifier
 *
 * This function supports two approaches:
 * 1. Template-based (legacy): Uses HTML templates for rendering results
 * 2. Component-based (modern): Uses Glimmer components for rendering results
 *
 * The component-based approach is preferred as it centralizes hashtag behavior
 * in the HashtagAutocompleteResults component, making the autocomplete call simpler.
 *
 * @param {Array} contextualHashtagConfiguration - The hashtag datasource types in priority order
 * @param {Object} autocompleteOptions - Additional options to merge
 * @param {boolean} [autocompleteOptions.useComponent=true] - Whether to use component-based approach
 * @returns {Object} Options for DAutocomplete modifier
 */
/**
 * Returns hashtag autocomplete options for the DAutocomplete modifier
 *
 * This function supports two approaches:
 * 1. Template-based (legacy): Uses HTML templates for rendering results
 * 2. Component-based (modern): Uses Glimmer components for rendering results
 *
 * @param {Array} contextualHashtagConfiguration - The hashtag datasource types in priority order
 * @param {Object} autocompleteOptions - Additional options to merge
 * @param {boolean} [autocompleteOptions.useComponent=true] - Whether to use component-based approach
 * @returns {Object} Options for DAutocomplete modifier
 */
export function hashtagAutocompleteOptions(
  contextualHashtagConfiguration,
  autocompleteOptions
) {
  // Get component from owner if available
  const component = autocompleteOptions.component || HashtagAutocompleteResults;

  // Legacy template-based approach for backward compatibility
  const legacyOptions = {
    template: renderHashtagAutocomplete,
    scrollElementSelector: ".hashtag-autocomplete__fadeout",
    key: "#",
    transformComplete: (obj) => obj.ref,
    dataSource: (term) => {
      if (term.match(/\s/)) {
        return null;
      }
      return _searchGeneric(term, contextualHashtagConfiguration);
    },
    triggerRule: async (_, opts) => await hashtagTriggerRule(opts),
  };

  // Modern component-based approach
  const componentOptions = {
    component,
    key: component.TRIGGER_KEY || "#",
    transformComplete: component.transformComplete || ((obj) => obj.ref),
    dataSource: (term) => {
      if (typeof component.dataSource === "function") {
        return component.dataSource(term, { contextualHashtagConfiguration });
      }

      // Fallback to legacy search
      if (term.match(/\s/)) {
        return null;
      }
      return _searchGeneric(term, contextualHashtagConfiguration);
    },
    triggerRule: component.shouldTrigger || hashtagTriggerRule,
  };

  // Common options for both approaches
  const commonOptions = {
    autoSelectFirstSuggestion: true,
  };

  // Determine which approach to use
  const useComponent = autocompleteOptions.useComponent !== false;

  return {
    ...(useComponent ? {} : legacyOptions), // Only include legacy options if not using component
    ...commonOptions,
    ...componentOptions, // Always include component options (component will be prioritized if supported)
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
function _searchGeneric(term, contextualHashtagConfiguration) {
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
