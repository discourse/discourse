import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class Filter extends Component {
  @service sidebarState;

  willDestroy() {
    super.willDestroy(...arguments);
    this.sidebarState.clearFilter();
  }

  get shouldDisplay() {
    return this.sidebarState.currentPanel.filterable;
  }

  get displayClearFilter() {
    return this.sidebarState.filter.length > 0;
  }

  @action
  setFilter(event) {
    this.sidebarState.filter = event.target.value.toLowerCase();
  }

  @action
  handleEscape(event) {
    if (event.key === "Escape") {
      event.stopPropagation();

      if (this.sidebarState.filter.length > 0) {
        this.sidebarState.filter = "";
      } else {
        event.target.blur();
      }
    }
  }

  @action
  clearFilter() {
    this.sidebarState.clearFilter();
    document.querySelector(".sidebar-filter__input").focus();
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-filter">
        <input
          {{on "input" this.setFilter}}
          {{on "keydown" this.handleEscape}}
          value={{this.sidebarState.filter}}
          placeholder={{i18n "sidebar.filter"}}
          type="text"
          class="sidebar-filter__input"
        />

        {{#if this.displayClearFilter}}
          <DButton
            @action={{this.clearFilter}}
            @icon="times"
            class="sidebar-filter__clear"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
