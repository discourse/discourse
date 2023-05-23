import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class SidebarHamburgerDropdown extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service siteSettings;

  @action
  triggerRenderedAppEvent() {
    this.appEvents.trigger("sidebar-hamburger-dropdown:rendered");
  }

  get collapsableSections() {
    if (
      this.siteSettings.navigation_menu === "header dropdown" &&
      !this.args.collapsableSections
    ) {
      return this.site.mobileView || this.site.narrowDesktopView;
    } else {
      this.args.collapsableSections;
    }
  }
}
