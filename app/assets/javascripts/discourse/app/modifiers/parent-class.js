import { service } from "@ember/service";
import Modifier from "ember-modifier";

export default class ParentClassModifier extends Modifier {
  @service elementClasses;

  modify(element, classes, { parentSelector }) {
    const parent = element.closest(parentSelector);

    if (!parent) {
      return;
    }

    this.elementClasses.registerClasses(
      this,
      parent,
      classes.flatMap((c) => c?.split(" ")).filter(Boolean)
    );
  }
}
