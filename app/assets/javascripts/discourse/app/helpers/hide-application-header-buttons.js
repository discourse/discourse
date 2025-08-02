import Helper from "@ember/component/helper";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";

export default class HideApplicationHeaderButtons extends Helper {
  @service header;

  registerHider(buttons) {
    this.header.registerHider(this, buttons);
  }

  compute([...buttons]) {
    scheduleOnce("afterRender", this, this.registerHider, buttons);
  }
}
