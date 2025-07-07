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
  @tracked selectedIndex = 0;

  constructor(owner, args) {
    super(owner, args);
    this.selectedIndex = this.args.data.selectedIndex || 0;
    //IMPT - this was the fix for the selectedIndex issue.
    this.markSelected();

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
    const menuElement = document.querySelector(
      '.fk-d-menu[data-identifier="d-autocomplete"]'
    );
    if (menuElement) {
      const links = menuElement.querySelectorAll("li a");

      // Remove 'selected' class from all links
      links.forEach((link) => link.classList.remove("selected"));

      // Add 'selected' class to current selection
      if (this.selectedIndex >= 0 && links[this.selectedIndex]) {
        links[this.selectedIndex].classList.add("selected");
      }
    }
  }

  @action
  setupTemplatedClickHandlers(element) {
    // When using templates, we need to manually set up click handlers
    // since the template renders raw HTML without component event handlers
    if (this.args.data.template) {
      const links = element.querySelectorAll("li a");

      links.forEach((link, index) => {
        link.addEventListener("click", (event) => {
          event.preventDefault();
          event.stopPropagation();
          this.args.data.onSelect(this.args.data.results[index], index, event);
        });
      });

      // Apply initial selection styling
      this.updateTemplatedSelection(links);
    }

    // Apply initial selection marking like original autocomplete
    this.markSelected();
  }

  @action
  updateTemplatedSelection(links) {
    // Clear existing selection
    links.forEach((link) => link.classList.remove("selected"));

    // Apply selected class to the appropriate link
    if (this.selectedIndex >= 0 && links[this.selectedIndex]) {
      links[this.selectedIndex].classList.add("selected");
    }
  }

  // Method to update selection from outside (called by modifier)
  updateSelection(newIndex) {
    this.selectedIndex = newIndex;

    // Update templated selection if using templates
    if (this.args.data.template) {
      const menuElement = document.querySelector(
        '.fk-d-menu[data-identifier="d-autocomplete"]'
      );
      if (menuElement) {
        const links = menuElement.querySelectorAll("li a");
        this.updateTemplatedSelection(links);
      }
    }
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
    <div {{didInsert this.setupTemplatedClickHandlers}}>
      {{{this.templateHTML}}}
    </div>
  </template>
}
