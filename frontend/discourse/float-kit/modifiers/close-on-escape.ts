import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";

interface FloatKitCloseOnEscapeSignature {
  Element: HTMLElement;
  Args: {
    Positional: [
      /** Called when Escape is pressed. */
      close: () => void,
    ];
  };
}

/**
 * The modifiers listening, oldest first. Each listens on the document, so with floats nested
 * every one would see the same Escape; only the newest acts on it.
 */
const listening: FloatKitCloseOnEscape[] = [];

export default class FloatKitCloseOnEscape extends Modifier<FloatKitCloseOnEscapeSignature> {
  declare closeFn: () => void;
  declare element: HTMLElement;

  constructor(owner: Owner, args: ArgsFor<FloatKitCloseOnEscapeSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element: HTMLElement,
    [closeFn]: FloatKitCloseOnEscapeSignature["Args"]["Positional"]
  ) {
    this.closeFn = closeFn;
    this.element = element;

    if (!listening.includes(this)) {
      listening.push(this);
    }
    document.addEventListener("keydown", this.check, { capture: true });
  }

  @bind
  check(event: KeyboardEvent) {
    if (event.key === "Escape" && listening.at(-1) === this) {
      event.stopPropagation();
      event.preventDefault();
      this.closeFn();
    }
  }

  cleanup() {
    const index = listening.indexOf(this);
    if (index !== -1) {
      listening.splice(index, 1);
    }
    document.removeEventListener("keydown", this.check, { capture: true });
  }
}
