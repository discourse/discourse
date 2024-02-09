import Helper from "@ember/component/helper";
import { inject as service } from "@ember/service";

export default class HtmlClass extends Helper {
  @service elementClasses;

  compute([...classes]) {
    this.elementClasses.registerClasses(
      this,
      document.documentElement,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
