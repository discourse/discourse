import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

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
  @tracked selectedIndex = this.args.data.selectedIndex || 0;
  wrapperElement;

  constructor(owner, args) {
    super(owner, args);
    // Register this component instance so the modifier can call its methods
    if (this.args.data.registerComponent) {
      this.args.data.registerComponent(this);
    }
  }

  @action
  updateSelectedIndex(newIndex) {
    this.selectedIndex = newIndex;
    // Apply DOM manipulation like original autocomplete
    this.markSelected();
  }

  markSelected() {
    // Find all links in the autocomplete menu and update selection like original
    if (this.wrapperElement) {
      const links = this.wrapperElement.querySelectorAll("li a");

      // Remove 'selected' class from all links
      links.forEach((link) => link.classList.remove("selected"));

      // Add 'selected' class to current selection
      if (this.selectedIndex >= 0 && links[this.selectedIndex]) {
        const selectedLink = links[this.selectedIndex];
        selectedLink.classList.add("selected");

        // Simple scrollIntoView to handle menu scrolling
        selectedLink.scrollIntoView({
          block: "nearest",
          behavior: "smooth",
        });
      }
    }
  }

  @action
  setup(element) {
    this.wrapperElement = element;

    if (this.args.data.template) {
      const links = this.wrapperElement.querySelectorAll("li a");

      links.forEach((link, index) => {
        link.addEventListener("click", (event) => {
          event.preventDefault();
          event.stopPropagation();
          this.args.data.onSelect(this.args.data.results[index], index, event);
        });
      });
    }

    this.markSelected();
  }

  @action
  handleClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.data.onSelect(result, index, event);
  }

  get templateHTML() {
    if (!this.args.data.template) {
      return "";
    }
    return this.args.data.template({ options: this.args.data.results });
  }

  <template>
    <div {{didInsert this.setup}}>
      {{{this.templateHTML}}}
    </div>
  </template>
}
