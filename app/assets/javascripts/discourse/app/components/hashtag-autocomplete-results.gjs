import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import BaseAutocompleteResults from "discourse/components/base-autocomplete-results";
import { ajax } from "discourse/lib/ajax";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { CANCELLED_STATUS } from "discourse/modifiers/d-autocomplete";

/**
 * Component for rendering hashtag autocomplete results with integrated hashtag-specific behavior
 * Extends BaseAutocompleteResults with hashtag-specific functionality.
 *
 * @component HashtagAutocompleteResults
 * @extends BaseAutocompleteResults
 * @param {Array} results - Array of hashtag results
 * @param {number} selectedIndex - Currently selected index
 * @param {Function} onSelect - Callback for item selection
 */
export default class HashtagAutocompleteResults extends BaseAutocompleteResults {
  /**
   * The trigger key for hashtag autocomplete
   *
   * @type {string}
   * @static
   */
  static TRIGGER_KEY = "#";

  /**
   * Transform a selected hashtag result to its reference value
   *
   * @param {Object} item - The selected hashtag item
   * @returns {string} The reference string to insert
   * @static
   * @override
   */
  static transformComplete(item) {
    return item.ref;
  }

  /**
   * Determines if the hashtag autocomplete should trigger
   *
   * @param {Object} opts - Options containing inCodeBlock method
   * @returns {Promise<boolean>} Whether autocomplete should trigger
   * @static
   * @override
   */
  static async shouldTrigger({ inCodeBlock }) {
    return !(await inCodeBlock());
  }

  /**
   * The data source function for hashtag autocomplete
   *
   * @param {string} term - The search term
   * @param {Object} options - Options containing contextualHashtagConfiguration
   * @returns {Promise<Array>|null} The search results or null if invalid term
   * @static
   * @override
   */
  static dataSource(term, options) {
    const contextualHashtagConfiguration =
      options?.contextualHashtagConfiguration;

    if (term && term.match(/\s/)) {
      return null;
    }

    return this._performDebouncedSearch(
      term,
      async (searchTerm) => {
        const response = await ajax("/hashtags/search.json", {
          data: {
            term: searchTerm,
            order: contextualHashtagConfiguration,
          },
        });

        if (response.results) {
          response.results.forEach((result) => {
            // Convert :emoji: in the result text to HTML safely
            result.text = htmlSafe(
              emojiUnescape(escapeExpression(result.text))
            );

            const opts = {
              preloaded: true,
              colors: result.colors,
              icon: result.icon,
              id: result.id,
              style_type: result.style_type,
              emoji: result.emoji,
            };

            const hashtagType = getHashtagTypeClasses()[result.type];
            result.icon = hashtagType.generateIconHTML(opts);
          });

          return response.results;
        }

        return CANCELLED_STATUS;
      },
      { contextualHashtagConfiguration }
    );
  }

  <template>
    <div
      class="autocomplete hashtag-autocomplete"
      {{didInsert this.handleInsert}}
    >
      <div class="hashtag-autocomplete__fadeout">
        <ul>
          {{#each @results as |option index|}}
            <li
              class="hashtag-autocomplete__option
                {{if (eq index @selectedIndex) 'selected'}}"
              data-index={{index}}
              {{on "click" (fn this.handleResultClick option index)}}
            >
              <a
                class="hashtag-autocomplete__link
                  {{if (eq index @selectedIndex) 'selected'}}"
                title={{option.description}}
                href="#"
              >
                {{#if option.icon}}
                  <span
                    class="hashtag-autocomplete__icon"
                  >{{option.icon}}</span>
                {{/if}}
                <span class="hashtag-autocomplete__text">
                  {{option.text}}
                  {{#if option.secondary_text}}
                    <span
                      class="hashtag-autocomplete__meta-text"
                    >({{option.secondary_text}})</span>
                  {{/if}}
                </span>
              </a>
            </li>
          {{/each}}
        </ul>
      </div>
    </div>
  </template>
}
