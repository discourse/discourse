import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class SidebarHamburgerDropdown extends Component {
  @service appEvents;
  @service currentUser;

  @action
  triggerRenderedAppEvent() {
    this.appEvents.trigger("sidebar-hamburger-dropdown:rendered");
  }
}
