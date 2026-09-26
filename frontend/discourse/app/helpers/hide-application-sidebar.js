import Helper from "@ember/component/helper";
import { scheduleOnce } from "@ember/runloop";
import { service } from "discourse/lib/service";
import SidebarStateService from "discourse/services/sidebar-state";

export default class HideApplicationSidebar extends Helper {
  @service(() => SidebarStateService) sidebarState;

  constructor() {
    super(...arguments);
    scheduleOnce("afterRender", this, this.registerHider);
  }

  registerHider() {
    this.sidebarState.registerHider(this);
  }

  compute() {}
}
