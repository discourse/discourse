import Helper from "@ember/component/helper";
import { service } from "@ember/service";

export default class HideApplicationFooter extends Helper {
  @service footer;

  constructor() {
    super(...arguments);
    this.footer.registerHider(this);
  }

  compute() {}
}
