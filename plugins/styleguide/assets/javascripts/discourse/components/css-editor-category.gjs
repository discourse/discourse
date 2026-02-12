import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import CssEditorVariable from "./css-editor-variable";

class VariableGroup {
  @tracked isExpanded = false;

  constructor(base, derivatives) {
    this.base = base;
    this.derivatives = derivatives;
  }

  get hasDerivatives() {
    return this.derivatives.length > 0;
  }
}

export default class CssEditorCategory extends Component {
  @tracked isExpanded = false;
  @tracked expandedGroups = new Set();

  get editable() {
    return this.args.editable !== false;
  }

  get filteredVariables() {
    const query = this.args.searchQuery?.toLowerCase();
    if (!query) {
      return this.args.variables;
    }
    return this.args.variables.filter((v) =>
      v.name.toLowerCase().includes(query)
    );
  }

  get variableGroups() {
    const variables = this.filteredVariables;
    const groups = [];
    const used = new Set();

    for (const variable of variables) {
      if (used.has(variable.name)) {
        continue;
      }

      const prefix = variable.name + "-";
      const derivatives = variables.filter(
        (v) => v.name !== variable.name && v.name.startsWith(prefix)
      );

      if (derivatives.length > 0) {
        derivatives.forEach((d) => used.add(d.name));
        used.add(variable.name);
        groups.push(new VariableGroup(variable, derivatives));
      }
    }

    for (const variable of variables) {
      if (!used.has(variable.name)) {
        groups.push(new VariableGroup(variable, []));
      }
    }

    return groups;
  }

  get hasVisibleVariables() {
    return this.filteredVariables.length > 0;
  }

  @action
  toggle() {
    this.isExpanded = !this.isExpanded;
  }

  @action
  toggleGroup(group) {
    group.isExpanded = !group.isExpanded;
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
            {{#each this.variableGroups as |group|}}
              <div class="css-editor-variable-group">
                <div class="css-editor-variable-group__base">
                  <CssEditorVariable
                    @variable={{group.base}}
                    @editable={{this.editable}}
                  />
                  {{#if group.hasDerivatives}}
                    <button
                      type="button"
                      class="css-editor-variable-group__toggle btn-flat btn-icon no-text"
                      title={{if
                        group.isExpanded
                        "Collapse derivatives"
                        "Expand derivatives"
                      }}
                      {{on "click" (fn this.toggleGroup group)}}
                    >
                      {{icon
                        (if group.isExpanded "chevron-down" "chevron-right")
                      }}
                      <span
                        class="css-editor-variable-group__derivative-count"
                      >{{group.derivatives.length}}</span>
                    </button>
                  {{/if}}
                </div>
                {{#if group.isExpanded}}
                  <div class="css-editor-variable-group__derivatives">
                    {{#each group.derivatives as |derivative|}}
                      <CssEditorVariable
                        @variable={{derivative}}
                        @editable={{this.editable}}
                      />
                    {{/each}}
                  </div>
                {{/if}}
              </div>
            {{/each}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
