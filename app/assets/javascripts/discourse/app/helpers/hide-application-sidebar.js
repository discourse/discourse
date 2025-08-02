import Helper from "@ember/component/helper";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";

export default class HideApplicationSidebar extends Helper {
  @service sidebarState;

  constructor() {
    super(...arguments);
    scheduleOnce("afterRender", this, this.registerHider);
  }

  registerHider() {
    this.sidebarState.registerHider(this);
  }

  compute() {}
}
