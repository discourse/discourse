import Helper from "@ember/component/helper";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";

export default class HideApplicationHeaderButtons extends Helper {
  @service header;

  constructor() {
    super(...arguments);
    scheduleOnce("afterRender", this, this.registerHider);
  }

  registerHider() {
    this.header.registerHider(this);
  }

  compute() {}
}
