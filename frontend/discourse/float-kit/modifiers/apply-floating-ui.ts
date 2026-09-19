import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { waitForPromise } from "@ember/test-waiters";
import { autoUpdate } from "@floating-ui/dom";
import Modifier, { type ArgsFor } from "ember-modifier";
import type { FloatKitTrigger } from "discourse/float-kit/lib/constants";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import {
  type PositioningOptions,
  updatePosition,
} from "discourse/float-kit/lib/update-position";
import { bind } from "discourse/lib/decorators";

interface FloatKitApplyFloatingUiSignature {
  Element: HTMLElement;
  Args: {
    Positional: [
      /** The reference the float is anchored to. */
      trigger: FloatKitTrigger,

      /** The positioning options, or `undefined` to use the defaults. */
      options: PositioningOptions | undefined,

      /** The float instance being positioned. */
      instance: FloatKitInstance,
    ];
  };
}

export default class FloatKitApplyFloatingUi extends Modifier<FloatKitApplyFloatingUiSignature> {
  declare instance: FloatKitInstance;
  declare options: PositioningOptions;
  declare cleanup?: () => void;

  constructor(owner: Owner, args: ArgsFor<FloatKitApplyFloatingUiSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.teardown());
  }

  modify(
    element: HTMLElement,
    [
      trigger,
      options,
      instance,
    ]: FloatKitApplyFloatingUiSignature["Args"]["Positional"]
  ) {
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
    if (this.instance.triggerElement?.isConnected === false) {
      return;
    }

    // Positioning is what finally gives a float its size, and it resolves off a promise the
    // test runtime cannot see. Without this, `settled()` returns while the float is still
    // unpositioned, so a test reads it at zero size — and anything that measures the float to
    // decide what to render, such as a virtualized list, computes an empty window from it.
    await waitForPromise(
      updatePosition(this.instance.trigger, this.instance.content, this.options)
    );
  }

  teardown() {
    this.cleanup?.();
  }
}
