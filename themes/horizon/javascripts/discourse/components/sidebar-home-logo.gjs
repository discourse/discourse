import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import HomeLogo from "discourse/components/header/home-logo";
import SidebarToggle from "discourse/components/header/sidebar-toggle";

export default class SidebarHomeLogo extends Component {
  @action
  toggleNavigationMenu() {
    getOwner(this).lookup("controller:application").send("toggleSidebar");
  }

  <template>
    <div class="sidebar-home-logo">
      <SidebarToggle
        @toggleNavigationMenu={{this.toggleNavigationMenu}}
        @showSidebar={{true}}
        @icon="bars"
      />
      <HomeLogo />
    </div>
  </template>
}
