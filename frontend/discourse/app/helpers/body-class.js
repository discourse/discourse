import Helper from "@ember/component/helper";
import { service } from "discourse/lib/service";
import ElementClassesService from "discourse/services/element-classes";

export default class BodyClass extends Helper {
  @service(() => ElementClassesService) elementClasses;

  compute([...classes]) {
    this.elementClasses.registerClasses(
      this,
      document.body,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
