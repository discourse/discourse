import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class Search extends Component {
  @service sidebarState;

  willDestroy() {
    super.willDestroy(...arguments);
  }

  get shouldDisplay() {
    return this.sidebarState.currentPanel.searchable;
  }

  @action
  onClick(event) {
    event?.preventDefault();
    return this.sidebarState.currentPanel.onSearchClick;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-search">
        <div class="sidebar-search__input-container">
          <DButton
            @action={{this.onClick}}
            @icon="magnifying-glass"
            class="btn-transparent sidebar-search__icon"
          />
          {{! template-lint-disable no-pointer-down-event-binding }}
          <input
            {{on "mousedown" this.onClick}}
            placeholder={{i18n "sidebar.search"}}
            type="text"
            enterkeyhint="done"
            class="sidebar-search__input"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
