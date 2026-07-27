import Route from "@ember/routing/route";
import { service } from "@ember/service";
import loadFaker from "discourse/lib/load-faker";
import scrollLock from "discourse/lib/scroll-lock";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { STYLEGUIDE_PANEL } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  @service header;
  @service sidebarState;

  async model() {
    await loadFaker(); // So that it can be used synchronously in styleguide components
  }

  activate() {
    this.sidebarState.setPanel(STYLEGUIDE_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.sidebarState.isForcingSidebar = true;
    this.sidebarState.forcingSidebarPanel = STYLEGUIDE_PANEL;

    // arriving via the header dropdown leaves it open
    if (this.sidebarState.sidebarHidden) {
      this.header.hamburgerVisible = false;
      scrollLock(false);
    }
  }

  deactivate() {
    this.sidebarState.setPanel(MAIN_PANEL);
    this.sidebarState.isForcingSidebar = false;
    this.sidebarState.forcingSidebarPanel = null;
  }
}
