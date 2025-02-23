import { registerDestructor } from "@ember/destroyable";
import { autoUpdate } from "@floating-ui/dom";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import { updatePosition } from "float-kit/lib/update-position";

export default class FloatKitApplyFloatingUi extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.teardown());
  }

  modify(element, [trigger, options, instance]) {
    instance.content = element;
    this.instance = instance;
    this.options = options ?? {};

    if (this.options.autoUpdate) {
      this.cleanup = autoUpdate(trigger, element, this.update);
    } else {
      this.update();
    }
  }

  @bind
  async update() {
    await updatePosition(
      this.instance.trigger,
      this.instance.content,
      this.options
    );
  }

  teardown() {
    this.cleanup?.();
  }
}
