import Component from "@glimmer/component";
import { service } from "@ember/service";
import BackToForum from "./back-to-forum";
import Filter from "./filter";
import FilterNoResults from "./filter-no-results";
import ToggleAllSections from "./toggle-all-sections";

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
          <Filter />
        </div>
      </div>
      <FilterNoResults @sections={{@sections}} />
    {{/if}}
  </template>
}
