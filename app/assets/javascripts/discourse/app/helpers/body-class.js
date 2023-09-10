import Helper from "@ember/component/helper";
import { inject as service } from "@ember/service";

export default class BodyClass extends Helper {
  @service bodyClasses;

  compute([...classes]) {
    this.bodyClasses.registerClasses(
      this,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
