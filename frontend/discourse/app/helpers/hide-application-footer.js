import Helper from "@ember/component/helper";
import { service } from "discourse/lib/service";
import FooterService from "discourse/services/footer";

export default class HideApplicationFooter extends Helper {
  @service(() => FooterService) footer;

  constructor() {
    super(...arguments);
    this.footer.registerHider(this);
  }

  compute() {}
}
