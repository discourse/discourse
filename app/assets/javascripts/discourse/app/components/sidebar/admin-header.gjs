import Component from "@glimmer/component";
import { service } from "@ember/service";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";
import BackToForum from "./back-to-forum";
import Filter from "./filter";
import ToggleAllSections from "./toggle-all-sections";

export default class AdminHeader extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.isCurrentPanel(ADMIN_PANEL);
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="sidebar-admin-header">
        <div class="sidebar-admin-header__row">
          <BackToForum />
          <ToggleAllSections @sections={{@sections}} />
        </div>
        <div class="sidebar-admin-header__row">
          <Filter />
        </div>
      </div>
    {{/if}}
  </template>
}
