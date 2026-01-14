import Helper from "@ember/component/helper";
import { service } from "@ember/service";

export default class ElementClass extends Helper {
  @service elementClasses;

  compute([...classes], { target }) {
    if (!target) {
      return;
    }

    this.elementClasses.registerClasses(
      this,
      target,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
