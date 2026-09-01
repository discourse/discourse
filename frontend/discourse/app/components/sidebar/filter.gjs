import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

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
    this.sidebarState.filter = event.target.value;
  }

  @action
  clearFilter() {
    this.sidebarState.clearFilter();
    document.querySelector(".sidebar-filter__input").focus();
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-filter">
        <div class="sidebar-filter__input-container">
          <input
            class="sidebar-filter__input"
            enterkeyhint="done"
            placeholder={{i18n "sidebar.filter_links"}}
            type="text"
            value={{this.sidebarState.filter}}
            {{on "input" this.setFilter}}
          />

          {{#if this.displayClearFilter}}
            <DButton
              class="sidebar-filter__clear btn-transparent"
              @action={{this.clearFilter}}
              @icon="xmark"
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
