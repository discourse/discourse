import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import CssEditorVariable from "./css-editor-variable";

export default class CssEditorCategory extends Component {
  @tracked isExpanded = false;

  get filteredVariables() {
    const query = this.args.searchQuery?.toLowerCase();
    if (!query) {
      return this.args.variables;
    }
    return this.args.variables.filter((v) =>
      v.name.toLowerCase().includes(query)
    );
  }

  get hasVisibleVariables() {
    return this.filteredVariables.length > 0;
  }

  @action
  toggle() {
    this.isExpanded = !this.isExpanded;
  }

  <template>
    {{#if this.hasVisibleVariables}}
      <div class="css-editor-category">
        <button
          type="button"
          class="css-editor-category__header"
          {{on "click" this.toggle}}
        >
          <span class="css-editor-category__title">{{@categoryName}}</span>
          <span
            class="css-editor-category__count"
          >{{this.filteredVariables.length}}</span>
          {{icon (if this.isExpanded "chevron-down" "chevron-right")}}
        </button>
        {{#if this.isExpanded}}
          <div class="css-editor-category__body">
            {{#each this.filteredVariables as |variable|}}
              <CssEditorVariable @variable={{variable}} />
            {{/each}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
