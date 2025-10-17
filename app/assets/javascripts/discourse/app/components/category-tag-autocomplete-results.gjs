import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq } from "truth-helpers";
import BaseAutocompleteResults from "discourse/components/base-autocomplete-results";
import categoryLink from "discourse/helpers/category-link";
import { ajax } from "discourse/lib/ajax";
import { SEPARATOR } from "discourse/lib/category-hashtags";
import { iconHTML } from "discourse/lib/icon-library";
import { TAG_HASHTAG_POSTFIX } from "discourse/lib/tag-hashtags";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";

/**
 * Component for rendering category and tag autocomplete results
 * Extends BaseAutocompleteResults with category/tag-specific functionality.
 *
 * @component CategoryTagAutocompleteResults
 * @extends BaseAutocompleteResults
 * @param {Array} results - Array of category/tag results
 * @param {number} selectedIndex - Currently selected index
 * @param {Function} onSelect - Callback for item selection
 */
export default class CategoryTagAutocompleteResults extends BaseAutocompleteResults {
  /**
   * The trigger key for category/tag autocomplete
   *
   * @type {string}
   * @static
   */
  static TRIGGER_KEY = "#";

  /**
   * Transform a selected category/tag result to its text representation
   *
   * @param {Object} item - The selected category/tag item
   * @returns {string} The text to insert
   * @static
   * @override
   */
  static transformComplete(item) {
    return item.text;
  }

  /**
   * The data source function for category/tag autocomplete
   *
   * @param {string} term - The search term
   * @param {Object} options - Options containing siteSettings
   * @returns {Promise<Array>} The search results
   * @static
   * @override
   */
  static dataSource(term, options) {
    const siteSettings = options?.siteSettings;
    const limit = 5;

    return this._performDebouncedSearch(
      term,
      async (searchTerm) => {
        // First search for categories
        let categories = Category.search(searchTerm, { limit });
        const numOfCategories = categories.length;

        // Convert categories to the expected format
        categories = categories.map((category) => {
          return {
            model: category,
            text: Category.slugFor(category, SEPARATOR, 2),
          };
        });

        // If we still have room in the limit and tagging is enabled, search for tags
        if (numOfCategories !== limit && siteSettings?.tagging_enabled) {
          const response = await ajax("/tags/filter/search", {
            data: { limit: limit - numOfCategories, q: searchTerm },
          });

          if (response.results) {
            const categoryNames = categories.map((c) => c.model.get("name"));

            const tags = response.results.map((tag) => {
              // Ensure tag names don't conflict with categories
              tag.text = categoryNames.includes(tag.text)
                ? `${tag.text}${TAG_HASHTAG_POSTFIX}`
                : tag.text;
              return tag;
            });

            return [...categories, ...tags];
          }
        }

        return categories;
      },
      { siteSettings }
    );
  }

  <template>
    <div
      class="autocomplete ac-category-or-tag"
      {{didInsert this.handleInsert}}
    >
      <ul>
        {{#each @results as |option index|}}
          <li
            data-index={{index}}
            class={{if (eq index @selectedIndex) "selected"}}
            {{on "click" (fn this.handleResultClick option index)}}
          >
            <a href class={{if (eq index @selectedIndex) "selected"}}>
              {{#if option.model}}
                {{! Category }}
                <span class="text-content">
                  {{categoryLink
                    option.model
                    allowUncategorized=true
                    link=false
                  }}
                </span>
              {{else}}
                {{! Tag }}
                {{{iconHTML "tag"}}}
                <span class="text-content">
                  {{option.text}}
                  x
                  {{option.count}}
                </span>
              {{/if}}
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
