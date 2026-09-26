import Helper from "@ember/component/helper";
import { service } from "discourse/lib/service";
import ElementClassesService from "discourse/services/element-classes";

export default class ElementClass extends Helper {
  @service(() => ElementClassesService) elementClasses;

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
