import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";
import { i18n } from "discourse-i18n";

export default class Search extends Component {
  @service sidebarState;

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
          <DShortcut @keys="mod+/" as |shortcut|>
            {{! eslint-disable ember/template-no-pointer-down-event-binding }}
            <input
              placeholder={{i18n "sidebar.search"}}
              type="text"
              enterkeyhint="done"
              class="sidebar-search__input"
              aria-keyshortcuts={{shortcut.aria}}
              {{on "mousedown" this.onClick}}
            />
            <shortcut.Kbd class="sidebar-search__shortcut-hint" />
          </DShortcut>
        </div>
      </div>
    {{/if}}
  </template>
}
