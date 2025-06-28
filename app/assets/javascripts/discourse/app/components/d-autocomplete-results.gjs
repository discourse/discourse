import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq } from "truth-helpers";

/**
 * Component for rendering autocomplete results in a d-menu
 *
 * @component DAutocompleteResults
 * @param {Array} data.results - Array of autocomplete results
 * @param {number} data.selectedIndex - Currently selected index
 * @param {Function} data.onSelect - Callback for item selection
 * @param {Function} [data.template] - Optional template function for custom rendering
 */
export default class DAutocompleteResults extends Component {
  @action
  handleClick(result, index, event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.data.onSelect(result, index, event);
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

      // Apply selected class to the appropriate link
      if (
        this.args.data.selectedIndex >= 0 &&
        links[this.args.data.selectedIndex]
      ) {
        links[this.args.data.selectedIndex].classList.add("selected");
      }
    }
  }

  get isComponentTemplate() {
    // Check if we have a component-friendly template
    return this.args.data.componentTemplate;
  }

  get templateItems() {
    if (this.isComponentTemplate) {
      // Component template returns structured data for each item
      return this.args.data.componentTemplate({
        options: this.args.data.results,
      });
    }
    return [];
  }

  get templateHTML() {
    if (this.args.data.template && !this.isComponentTemplate) {
      // Call original template with full results array, matching original jQuery autocomplete behavior
      return this.args.data.template({ options: this.args.data.results });
    }
    return "";
  }

  getResultHTML(result) {
    // Default template for individual result
    if (typeof result === "string") {
      return `<span class="username">${result}</span>`;
    }

    if (result.username) {
      let html = `<span class="username">${result.username}</span>`;
      if (result.avatar_template) {
        const avatar = result.avatar_template.replace("{size}", "25");
        html = `<img class="avatar" src="${avatar}" width="25" height="25" alt="${result.username}"> ${html}`;
      }
      if (result.name) {
        html += `<span class="name">${result.name}</span>`;
      }
      return html;
    }

    return result.toString();
  }

  <template>
    {{#if this.isComponentTemplate}}
      {{! Component-friendly template - we handle the structure }}
      <div class="autocomplete ac-user">
        <ul>
          {{#each this.templateItems as |templateItem index|}}
            <li>
              <a
                class="{{templateItem.cssClasses}}
                  {{if (eq index @data.selectedIndex) 'selected' ''}}"
                title={{templateItem.title}}
                {{on "click" (fn this.handleClick templateItem.item index)}}
                data-index={{index}}
              >
                {{{templateItem.content}}}
              </a>
            </li>
          {{/each}}
        </ul>
      </div>
    {{else if @data.template}}
      {{! Original template - it handles the complete structure including wrapper }}
      <div {{didInsert this.setupTemplatedClickHandlers}}>
        {{{this.templateHTML}}}
      </div>
    {{else}}
      {{! Default structure with individual items }}
      <div class="autocomplete ac-user">
        <ul>
          {{#each @data.results as |result index|}}
            <li>
              <a
                class={{if (eq index @data.selectedIndex) "selected" ""}}
                {{on "click" (fn this.handleClick result index)}}
                data-index={{index}}
              >
                {{{this.getResultHTML result}}}
              </a>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
