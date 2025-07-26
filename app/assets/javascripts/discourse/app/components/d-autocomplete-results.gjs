import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { htmlSafe } from "@ember/template";

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
  wrapperElement;
  isInitialRender = true;
  clickHandler;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  cleanup() {
    if (this.clickHandler && this.wrapperElement) {
      this.wrapperElement.removeEventListener("click", this.clickHandler);
    }
  }

  // Use getters that access modifier's tracked properties for reactivity
  get results() {
    return this.args.data.getResults?.() || [];
  }

  get selectedIndex() {
    return this.args.data.getSelectedIndex?.() || 0;
  }

  markSelected() {
    // This is a more imperative approach that's meant to be compatible with the pre-existing autocomplete templates,
    // we should refactor in future to use component templates that are more declarative in setting the `selected` class.

    // Find all links in the autocomplete menu and update selection
    if (this.wrapperElement) {
      const links = this.wrapperElement.querySelectorAll("li a");

      // Remove 'selected' class from all links
      links.forEach((link) => link.classList.remove("selected"));

      // Add 'selected' class to current selection
      if (this.selectedIndex >= 0 && links[this.selectedIndex]) {
        const selectedLink = links[this.selectedIndex];
        selectedLink.classList.add("selected");

        // Only scroll during navigation, not initial render
        if (!this.isInitialRender) {
          selectedLink.scrollIntoView({
            block: "nearest",
            behavior: "smooth",
          });
        }
      }
    }
  }

  attachClickHandlers() {
    if (this.args.data.template && this.wrapperElement) {
      // Remove existing click handler if it exists
      if (this.clickHandler) {
        this.wrapperElement.removeEventListener("click", this.clickHandler);
      }

      // Use event delegation - attach single handler to wrapper element
      this.clickHandler = (event) => {
        try {
          // Find the clicked link and its index
          const clickedLink = event.target.closest("li a");
          if (!clickedLink) {return;}

          event.preventDefault();
          event.stopPropagation();

          // Find the index of the clicked link
          const links = this.wrapperElement.querySelectorAll("li a");
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
      };

      this.wrapperElement.addEventListener("click", this.clickHandler);
    }
  }

  @action
  setup(element) {
    this.wrapperElement = element;
    this.attachClickHandlers();
    this.markSelected();
  }

  @action
  updateSelection() {
    // Called when template or selection changes
    this.isInitialRender = false;

    // Re-attach click handlers since DOM may have been updated
    this.attachClickHandlers();

    this.markSelected();
  }

  get templateHTML() {
    if (!this.args.data.template) {
      return "";
    }

    return htmlSafe(this.args.data.template({ options: this.results }));
  }

  <template>
    <div
      {{didInsert this.setup}}
      {{didUpdate this.updateSelection this.selectedIndex this.templateHTML}}
    >
      {{this.templateHTML}}
    </div>
  </template>
}
