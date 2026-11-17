import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";

interface DCloseOnClickOutsideOptions {
  /** A selector for an element that does not count as outside. Ignored when `target` is set. */
  targetSelector?: string;
  /** A selector for a second element that does not count as outside. */
  secondaryTargetSelector?: string;
  /** An element that does not count as outside. Takes precedence over `targetSelector`. */
  target?: Element | null;
}

interface DCloseOnClickOutsideSignature {
  Element: Element;
  Args: {
    Positional: [
      /** Called with the pointerdown event when the pointer goes down outside. */
      closeFn: (event: PointerEvent) => void,
      options?: DCloseOnClickOutsideOptions,
    ];
  };
}

/**
 * Calls `closeFn` when the pointer goes down anywhere outside the element and the
 * optional targets.
 */
export default class DCloseOnClickOutside extends Modifier<DCloseOnClickOutsideSignature> {
  declare closeFn: (event: PointerEvent) => void;
  declare element: Element;
  declare target: Element | null | undefined;
  declare targetSelector: string | undefined;
  declare secondaryTargetSelector: string | undefined;

  constructor(owner: Owner, args: ArgsFor<DCloseOnClickOutsideSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element: Element,
    [
      closeFn,
      {
        targetSelector,
        secondaryTargetSelector,
        target,
      } = {} as DCloseOnClickOutsideOptions,
    ]: DCloseOnClickOutsideSignature["Args"]["Positional"]
  ) {
    this.closeFn = closeFn;
    this.element = element;
    this.target = target;
    this.targetSelector = targetSelector;
    this.secondaryTargetSelector = secondaryTargetSelector;

    document.addEventListener("pointerdown", this.check, {
      passive: true,
    });
  }

  @bind
  check(event: PointerEvent) {
    if (this.element.contains(event.target as Node | null)) {
      return;
    }

    // An unset selector is stringified to "undefined", which matches nothing.
    const target =
      this.target ?? document.querySelector(this.targetSelector as string);

    if (
      target?.contains(event.target as Node | null) ||
      (this.secondaryTargetSelector &&
        document
          .querySelector(this.secondaryTargetSelector)
          ?.contains(event.target as Node | null))
    ) {
      return;
    }

    this.closeFn(event);
  }

  cleanup() {
    // Removal matches on `capture` alone, so the `passive` flag here is inert.
    document.removeEventListener("pointerdown", this.check, {
      passive: true,
    } as EventListenerOptions);
  }
}
