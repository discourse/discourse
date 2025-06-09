import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class Filter extends Component {
  @service sidebarState;
  @service router;
  @service currentUser;

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
            {{on "input" this.setFilter}}
            value={{this.sidebarState.filter}}
            placeholder={{i18n "sidebar.filter_links"}}
            type="text"
            enterkeyhint="done"
            class="sidebar-filter__input"
          />

          {{#if this.displayClearFilter}}
            <DButton
              @action={{this.clearFilter}}
              @icon="xmark"
              class="sidebar-filter__clear"
            />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
