import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class FilterField extends Component {
  @service routeInspectorState;

  @action
  handleInput(event) {
    this.routeInspectorState.setFilter(event.target.value);
  }

  @action
  clearFilter() {
    this.routeInspectorState.setFilter("");
  }

  @action
  toggleCaseSensitivity() {
    this.routeInspectorState.toggleCaseSensitivity();
  }

  <template>
    <div class="filter-field">
      <div class="filter-field__icon">
        {{icon "lucide-funnel"}}
      </div>
      <input
        type="text"
        class="filter-field__input"
        placeholder={{i18n (themePrefix "route_inspector.filter_placeholder")}}
        value={{this.routeInspectorState.filter}}
        {{on "input" this.handleInput}}
      />
      <button
        type="button"
        class={{concatClass
          "filter-field__case-sensitivity-btn"
          (if this.routeInspectorState.filterCaseSensitive "--active")
        }}
        {{on "click" this.toggleCaseSensitivity}}
      >
        {{icon "material-match-case"}}
      </button>
      {{#if this.routeInspectorState.filter}}
        <button
          type="button"
          class="filter-field__clear-btn"
          {{on "click" this.clearFilter}}
        >
          {{icon "lucide-x"}}
        </button>
      {{/if}}
    </div>
  </template>
}
