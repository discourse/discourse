import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY, isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { CANCELLED_STATUS } from "discourse/modifiers/d-autocomplete";

/**
 * Base component for autocomplete results with shared functionality.
 * This is an abstract component that should be extended by specific autocomplete components.
 *
 * When using DAutocomplete with a component approach, extend this base component
 * to create specialized autocomplete components for different trigger keys.
 * This enables a more object-oriented, maintainable approach compared to the
 * template-based legacy approach.
 *
 * To create a specialized autocomplete component:
 * 1. Extend this class
 * 2. Define static TRIGGER_KEY property for your specific trigger character
 * 3. Override static dataSource method for fetching results
 * 4. Override static transformComplete method for formatting selected items
 * 5. Implement your template for rendering results
 *
 * The base class handles:
 * - Caching of results
 * - Debounced searching
 * - Selection management
 * - Common event handlers
 *
 * @component BaseAutocompleteResults
 * @abstract
 * @param {Array} results - Array of autocomplete results
 * @param {number} selectedIndex - Currently selected index
 * @param {Function} onSelect - Callback for item selection
 *
 * @example
 * ```javascript
 * // Creating a specialized autocomplete component
 * export default class CustomAutocompleteResults extends BaseAutocompleteResults {
 *   static TRIGGER_KEY = "$";
 *
 *   static transformComplete(item) {
 *     return item.value;
 *   }
 *
 *   static dataSource(term, options) {
 *     return this._performDebouncedSearch(term, async (searchTerm) => {
 *       // Your custom search logic
 *       return results;
 *     });
 *   }
 *
 *   <template>
 *     // Your custom rendering
 *   </template>
 * }
 * ```
 */
export default class BaseAutocompleteResults extends Component {
  /**
   * Whether to automatically select the first suggestion
   *
   * @returns {boolean}
   * @static
   */
  static get autoSelectFirstSuggestion() {
    return true;
  }

  /**
   * Clear the cache if it's older than the specified time
   *
   * @param {number} maxAge - Maximum age in milliseconds
   * @static
   */
  static clearStaleCache(maxAge = 30000) {
    if (new Date() - this._cacheTime > maxAge) {
      this._cache = {};
    }
  }

  /**
   * Get a cached result for the given term
   *
   * @param {string} term - Search term
   * @returns {Array|undefined} - Cached results or undefined if not found
   * @static
   */
  static getCachedResult(term) {
    this.clearStaleCache();
    return this._cache[term];
  }

  /**
   * Update the search cache with results
   *
   * @param {string} term - The search term
   * @param {Array} results - The search results
   * @returns {Array} The results
   * @static
   * @protected
   */
  static _updateSearchCache(term, results) {
    this._cache[term] = results;
    this._cacheTime = new Date();
    return results;
  }

  /**
   * Helper method to perform debounced search
   *
   * @param {string} term - Search term
   * @param {Function} searchFunction - Function to perform the actual search
   * @param {Object} [options] - Additional options
   * @returns {Promise<Array>} Search results
   * @static
   * @protected
   */
  static _performDebouncedSearch(term, searchFunction, options = {}) {
    if (this._currentSearch) {
      this._currentSearch.abort?.();
      this._currentSearch = null;
    }

    const cached = this.getCachedResult(term);
    if (cached) {
      return Promise.resolve(cached);
    }

    return new Promise((resolve) => {
      let timeoutPromise = isTesting()
        ? null
        : discourseLater(() => {
            resolve(CANCELLED_STATUS);
          }, options.timeout || 5000);

      const debouncedSearch = (term, resultFunc) => {
        discourseDebounce(
          this,
          async () => {
            try {
              const result = await searchFunction(term, options);
              resultFunc(result);
            } catch (e) {
              if (e.name !== "AbortError") {
                console.error(`[${this.name}] search error:`, e);
              }
              resultFunc(CANCELLED_STATUS);
            }
          },
          INPUT_DELAY
        );
      };

      debouncedSearch(term, (result) => {
        cancel(timeoutPromise);
        resolve(this._updateSearchCache(term, result));
      });
    });
  }

  /**
   * Abstract method that must be implemented by subclasses
   * to define the search function for this autocomplete type
   *
   * @param {string} term - The search term
   * @param {Object} options - Additional options specific to this autocomplete type
   * @returns {Promise<Array>} - Search results
   * @static
   * @abstract
   */
  static dataSource(term, options) {
    throw new Error("dataSource must be implemented by subclass");
  }

  /**
   * Transform a selected result to its reference value
   * Default implementation returns the item unchanged
   *
   * @param {Object} item - The selected item
   * @returns {string} The reference string to insert
   * @static
   */
  static transformComplete(item) {
    return item;
  }

  /**
   * Determines if the autocomplete should trigger
   * Default implementation always returns true
   *
   * @param {Object} opts - Options containing contextual methods
   * @returns {Promise<boolean>} Whether autocomplete should trigger
   * @static
   */
  static async shouldTrigger() {
    return true;
  }

  /**
   * Common cache storage shared by all autocomplete instances
   * Stores results keyed by search term
   *
   * @static
   * @private
   */
  static _cache = {};

  /**
   * Timestamp of the last cache update
   *
   * @static
   * @private
   */
  static _cacheTime;

  /**
   * Current ajax search request
   *
   * @static
   * @private
   */
  static _currentSearch;

  /**
   * Get the ID of the currently selected result
   *
   * @returns {string|null} The ID of the selected result or null if none selected
   */
  get selectedResultId() {
    if (
      this.args.selectedIndex >= 0 &&
      this.args.results?.[this.args.selectedIndex]
    ) {
      return this.args.results[this.args.selectedIndex].id;
    }
    return null;
  }

  /**
   * Handle clicking on a result
   *
   * @param {Object} result - The clicked result
   * @param {number} index - The index of the clicked result
   * @param {Event} event - The click event
   */
  @action
  handleResultClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();

    if (typeof this.args.onSelect === "function") {
      this.args.onSelect(result, index, event);
    }
  }

  /**
   * Handle initial rendering of the component
   * Used to scroll the selected item into view
   *
   * @param {HTMLElement} element - The component's root element
   */
  @action
  handleInsert(element) {
    // Scroll the selected item into view if needed
    if (this.args.selectedIndex >= 0) {
      const selectedItem = element.querySelector(
        `[data-index="${this.args.selectedIndex}"]`
      );
      if (selectedItem) {
        selectedItem.scrollIntoView({ block: "nearest", behavior: "smooth" });
      }
    }
  }

  <template>{{yield}}</template>
}
