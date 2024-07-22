import Helper from "@ember/component/helper";
import { service } from "@ember/service";

export default class DocumentClass extends Helper {
  @service elementClasses;

  compute([...classes]) {
    this.elementClasses.registerClasses(
      this,
      document.body,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
