import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";

/**
 * Base component for all autocomplete result components
 * Provides common functionality for rendering autocomplete results
 *
 * @component BaseAutocompleteResults
 * @param {Array} results - Array of autocomplete results
 * @param {number} selectedIndex - Currently selected index in the results list
 * @param {Function} onSelect - Callback function triggered when a result is selected
 * @param {Function} onRender - Optional callback function triggered after component renders
 */
export default class BaseAutocompleteResults extends Component {
  constructor() {
    super(...arguments);

    assert(
      "BaseAutocompleteResults is an abstract component and must be extended. " +
        "Create a subclass like UserAutocompleteResults or HashtagAutocompleteResults.",
      this.constructor !== BaseAutocompleteResults
    );
  }

  /**
   * Handle result click events
   *
   * @param {Object} result - The result object that was clicked
   * @param {number} index - Index of the clicked result
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
   * Handle component insertion into DOM
   * Scrolls selected item into view if needed
   *
   * @param {HTMLElement} element - The root element of this component
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

    // Call onRender callback after initial render
    if (typeof this.args.onRender === "function") {
      this.args.onRender(this.args.results);
    }
  }

  /**
   * Scroll the selected item into view
   *
   * @param {HTMLElement} element - The root element of this component
   */
  scrollToSelected(element) {
    if (!element || this.args.selectedIndex < 0) {
      return;
    }

    const selectedItem = element.querySelector(
      `[data-index="${this.args.selectedIndex}"]`
    );

    if (selectedItem) {
      selectedItem.scrollIntoView({
        block: "nearest",
        behavior: "smooth",
      });
    }
  }

  /**
   * Handle component updates
   * Scrolls selected item into view and calls onRender callback after DOM updates
   *
   * @param {HTMLElement} element - The root element of this component
   */
  @action
  handleUpdate(element) {
    this.scrollToSelected(element);

    // Call onRender callback after DOM updates
    if (typeof this.args.onRender === "function") {
      this.args.onRender(this.args.results);
    }
  }

  <template>
    <div
      class="autocomplete"
      {{didInsert this.handleInsert}}
      {{didUpdate this.handleUpdate @selectedIndex}}
    >
      {{yield this.handleResultClick this.handleInsert}}
    </div>
  </template>
}
