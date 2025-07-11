import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";

/**
 * Autocomplete results component with keyboard navigation
 *
 * @component DAutocompleteResults
 *
 * @param {Array} results - Array of result items
 * @param {number} selectedIndex - Currently selected index
 * @param {string} searchTerm - Current search term
 * @param {boolean} isLoading - Loading state
 * @param {Component} template - Custom template for result items
 * @param {Function} onSelectResult - Callback when result is selected
 * @param {Function} onMoveSelection - Callback to move selection
 */
export default class DAutocompleteResults extends Component {
  @action
  selectResult(result, event) {
    this.args.onSelectResult(result, event);
  }

  @action
  handleClick(result, event) {
    event.preventDefault();
    event.stopPropagation();
    this.selectResult(result, event);
  }

  @action
  scrollToSelected() {
    const selectedElement = document.querySelector(
      `[data-autocomplete-index="${this.args.selectedIndex}"]`
    );

    if (selectedElement) {
      selectedElement.scrollIntoView({
        block: "nearest",
        behavior: "smooth",
      });
    }
  }

  <template>
    <div
      class="autocomplete-results"
      role="listbox"
      aria-label="Autocomplete suggestions"
    >
      {{#if @isLoading}}
        <div class="autocomplete-loading">
          Searching...
        </div>
      {{else if @results.length}}
        <ul class="autocomplete-results__list">
          {{#each @results as |result index|}}
            <li
              class="autocomplete-result
                {{if (eq index @selectedIndex) 'selected'}}"
              role="option"
              aria-selected={{if (eq index @selectedIndex) "true" "false"}}
              data-autocomplete-index={{index}}
              {{on "click" (fn this.handleClick result)}}
            >
              {{#if @template}}
                <@template
                  @data={{result}}
                  @index={{index}}
                  @searchTerm={{@searchTerm}}
                />
              {{else}}
                <span class="autocomplete-result__text">{{result}}</span>
              {{/if}}
            </li>
          {{/each}}
        </ul>
      {{else}}
        <div class="autocomplete-no-results">
          No results found for "{{@searchTerm}}"
        </div>
      {{/if}}
    </div>
  </template>
}
