import Helper from "@ember/component/helper";
import { scheduleOnce } from "@ember/runloop";
import { service } from "discourse/lib/service";
import HeaderService from "discourse/services/header";

export default class HideApplicationHeaderButtons extends Helper {
  @service(() => HeaderService) header;

  registerHider(buttons) {
    this.header.registerHider(this, buttons);
  }

  compute([...buttons]) {
    scheduleOnce("afterRender", this, this.registerHider, buttons);
  }
}
