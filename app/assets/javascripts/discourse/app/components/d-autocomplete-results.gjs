import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { htmlSafe } from "@ember/template";

// CSS selectors for autocomplete result items
const RESULT_ITEM_SELECTOR = "li a";
const SELECTED_RESULT_SELECTOR = "li a.selected";
const SELECTED_CLASS = "selected";

/**
 * Component for rendering autocomplete results in a d-menu
 *
 * @component DAutocompleteResults
 * @param {Array} data.results - Array of autocomplete results
 * @param {number} data.selectedIndex - Currently selected index
 * @param {Function} data.onSelect - Callback for item selection
 * @param {Function} data.template - Template function for rendering
 */
export default class DAutocompleteResults extends Component {
  isInitialRender = true;

  // Use getters that access modifier's tracked properties for reactivity
  get results() {
    return this.args.data.getResults?.() || [];
  }

  get selectedIndex() {
    return this.args.data.getSelectedIndex?.() || 0;
  }

  _applySelectedClass(wrapperElement, selectedIndex) {
    const links = wrapperElement.querySelectorAll(RESULT_ITEM_SELECTOR);

    // Always remove existing selected classes first
    const selectedElements = wrapperElement.querySelectorAll(
      SELECTED_RESULT_SELECTOR
    );
    selectedElements.forEach((element) =>
      element.classList.remove(SELECTED_CLASS)
    );

    // Add selected class to new selection if valid
    if (selectedIndex >= 0 && links[selectedIndex]) {
      links[selectedIndex].classList.add(SELECTED_CLASS);
    }

    return links;
  }

  markSelected(wrapperElement) {
    // This is a more imperative approach that's meant to be compatible with the pre-existing autocomplete templates,
    // we should refactor in future to use component templates that are more declarative in setting the `selected` class.

    if (!wrapperElement) {
      return;
    }
    // Find all links in the autocomplete menu and update selection
    const links = this._applySelectedClass(wrapperElement, this.selectedIndex);

    // Handle scrolling (only during navigation, not initial render)
    if (
      !this.isInitialRender &&
      this.selectedIndex >= 0 &&
      links[this.selectedIndex]
    ) {
      links[this.selectedIndex].scrollIntoView({
        block: "nearest",
        behavior: "smooth",
      });
    }
  }

  @action
  handleClick(event) {
    if (!this.args.data.template) {
      return;
    }

    try {
      event.preventDefault();
      event.stopPropagation();

      const clickedLink = event.target.closest(RESULT_ITEM_SELECTOR);
      if (!clickedLink) {
        return;
      }

      // Find the index of the clicked link
      const links = event.currentTarget.querySelectorAll(RESULT_ITEM_SELECTOR);
      const index = Array.from(links).indexOf(clickedLink);

      if (index >= 0) {
        // Call onSelect and handle any promise returned
        const result = this.args.data.onSelect(
          this.results[index],
          index,
          event
        );
        if (result && typeof result.then === "function") {
          result.catch((e) => {
            // eslint-disable-next-line no-console
            console.error("[autocomplete] onSelect promise rejected: ", e);
          });
        }
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[autocomplete] Click handler error: ", e);
    }
  }

  @action
  updateSelection(wrapperElement) {
    // Called when template or selection changes
    this.isInitialRender = false;
    this.markSelected(wrapperElement);
    
    // Call onRender callback after DOM is ready, matching original autocomplete.js behavior
    this.args.data.onRender?.(this.results);
  }

  get templateHTML() {
    if (!this.args.data.template) {
      return "";
    }

    const template = this.args.data.template({ options: this.results });

    if (!this.isInitialRender || this.selectedIndex < 0) {
      return htmlSafe(template);
    }

    const tempDiv = document.createElement("div");
    tempDiv.innerHTML = template;
    this._applySelectedClass(tempDiv, this.selectedIndex);

    return htmlSafe(tempDiv.innerHTML);
  }

  <template>
    <div
      {{didUpdate this.updateSelection this.selectedIndex this.templateHTML}}
      {{on "click" this.handleClick}}
    >
      {{this.templateHTML}}
    </div>
  </template>
}
