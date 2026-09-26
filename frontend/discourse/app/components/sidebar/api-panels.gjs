import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import ApiSections from "./api-sections";
import SidebarStateService from "discourse/services/sidebar-state";

export default class SidebarApiPanels extends Component {
  @service(() => SidebarStateService) sidebarState;

  get panelCssClass() {
    return `${this.sidebarState.currentPanel.key}-panel`;
  }

  <template>
    <div class="sidebar-sections {{this.panelCssClass}}">
      <ApiSections
        @collapsable={{@collapsableSections}}
        @expandActiveSection={{this.sidebarState.currentPanel.expandActiveSection}}
        @scrollActiveLinkIntoView={{this.sidebarState.currentPanel.scrollActiveLinkIntoView}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />
    </div>
  </template>
}
