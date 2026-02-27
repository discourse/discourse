import { registerDestructor } from "@ember/destroyable";
import { autoUpdate } from "@floating-ui/dom";
import Modifier from "ember-modifier";
import { updatePosition } from "discourse/float-kit/lib/update-position";
import { bind } from "discourse/lib/decorators";

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
      this.cleanup = autoUpdate(
        trigger,
        element,
        this.update,
        typeof this.options.autoUpdate === "object"
          ? this.options.autoUpdate
          : {}
      );
    } else {
      this.update();
    }
  }

  @bind
  async update() {
    if (!this.instance.trigger?.isConnected) {
      return;
    }

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
