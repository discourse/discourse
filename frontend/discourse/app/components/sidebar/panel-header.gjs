import Component from "@glimmer/component";
import { service } from "@ember/service";
import BackToForum from "discourse/components/sidebar/back-to-forum";
import Search from "discourse/components/sidebar/search";
import Filter from "./filter.gjs";
import FilterNoResults from "./filter-no-results.gjs";
import ToggleAllSections from "./toggle-all-sections.gjs";

export default class PanelHeader extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.currentPanel.displayHeader;
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-panel-header">
        <div class="sidebar-panel-header__row">
          <BackToForum />
          <ToggleAllSections @sections={{@sections}} />
        </div>
        <div class="sidebar-panel-header__row">
          <Search />
          <Filter />
        </div>
        <FilterNoResults @sections={{@sections}} />
      </div>
    {{/if}}
  </template>
}
