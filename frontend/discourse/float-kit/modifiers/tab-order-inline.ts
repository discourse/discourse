import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import {
  adjacentTabStop,
  tabStopsWithin,
} from "discourse/float-kit/lib/tab-order";
import { bind } from "discourse/lib/decorators";

interface FloatKitTabOrderInlineSignature {
  Element: HTMLElement;
  Args: {
    Positional: [
      /** The trigger the float hangs from, whose place in the page Tab should follow. */
      trigger: HTMLElement | null | undefined,
      /** Dismisses the float once focus has left it. */
      close: () => void,
    ];
  };
}

/**
 * Gives a float's content the tab order it would have had if it were rendered inline, directly
 * after its trigger.
 *
 * A float is portaled out of its trigger's subtree, and sequential focus follows document order,
 * so the portal's position in the document — not the trigger's — is what Tab actually follows.
 * That breaks the sequence in both directions: Tab off the end of the float's controls lands
 * wherever the portal sits, and the float's own controls are never reached at all, since nothing
 * leads into them from the trigger. Both halves are repaired here:
 *
 * - **Into** the float: a forward Tab at the trigger's last stop moves to the float's first stop,
 *   when it has one. A float offering nothing focusable is left alone, so Tab passes over it and
 *   out of the widget — which is what a plain listbox wants, since its rows are reached with the
 *   arrow keys rather than by tabbing.
 * - **Out of** the float: a Tab that would step off the end of the float's own stops dismisses it
 *   and continues from the TRIGGER. Forward that is the stop after the trigger; backward it is
 *   the trigger's own last stop, which is where the reader came in.
 *
 * Presses that merely move between the float's own controls are left to the browser.
 *
 * This is the alternative to `trapTab`, not a companion to it. Containment suits a float that is
 * genuinely modal — a real `aria-modal` dialog, which owns the screen until dismissed — and
 * strands a reader anywhere else, since a non-modal float shows nothing to say that Tab has
 * stopped meaning "move on".
 *
 * A float that also holds a scroll container should keep it out of the tab sequence with an
 * explicit `tabindex="-1"`: a browser that adopts scrollers as tab stops does so invisibly, so
 * such an element consumes a Tab press while being absent from the enumerations below.
 */
export default class FloatKitTabOrderInline extends Modifier<FloatKitTabOrderInlineSignature> {
  #boundTrigger: HTMLElement | null = null;
  #close?: () => void;
  #content?: HTMLElement;
  #trigger?: HTMLElement | null;

  constructor(owner: Owner, args: ArgsFor<FloatKitTabOrderInlineSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element: HTMLElement,
    [trigger, close]: FloatKitTabOrderInlineSignature["Args"]["Positional"]
  ) {
    this.#content = element;
    this.#trigger = trigger;
    this.#close = close;

    element.removeEventListener("keydown", this.handleContentKeydown);
    element.addEventListener("keydown", this.handleContentKeydown);

    // The trigger listener lives exactly as long as this modifier, which lives as long as the
    // float's content — so it is bound only while the float is open, which is the only time
    // entering it is meaningful. Rebound rather than assumed stable, since `modify` re-runs
    // whenever the trigger argument changes.
    //
    // CAPTURE phase, because a control inside the trigger may stop Tab from bubbling: a combobox
    // input does exactly that, to keep Tab from being pulled into a panel holding nothing but a
    // list. Capture is the only phase certain to see the press. That guard is preserved rather
    // than defeated — this handler declines a float with no stop of its own, so the press
    // continues to the trigger's own handling untouched.
    this.#boundTrigger?.removeEventListener(
      "keydown",
      this.handleTriggerKeydown,
      true
    );
    this.#boundTrigger = trigger ?? null;
    this.#boundTrigger?.addEventListener(
      "keydown",
      this.handleTriggerKeydown,
      true
    );
  }

  /** Forward Tab at the trigger's last stop enters the float, when the float has a stop to offer. */
  @bind
  handleTriggerKeydown(event: KeyboardEvent) {
    if (
      event.key !== "Tab" ||
      event.shiftKey ||
      event.isComposing ||
      event.defaultPrevented
    ) {
      return;
    }

    const content = this.#content;
    const trigger = this.#trigger;
    if (!content || !trigger) {
      return;
    }

    // Backward is deliberately not handled: the stop before the trigger is already the previous
    // element in the page, which is what a native Shift+Tab reaches.
    const triggerStops = tabStopsWithin(trigger);
    const lastTriggerStop = triggerStops.at(-1);
    if (lastTriggerStop && document.activeElement !== lastTriggerStop) {
      return;
    }

    const contentStops = tabStopsWithin(content);
    if (!contentStops.length) {
      return;
    }

    event.preventDefault();
    contentStops[0].focus();
  }

  /** A Tab that would step off the end of the float's own stops leaves it, from the trigger. */
  @bind
  handleContentKeydown(event: KeyboardEvent) {
    if (event.key !== "Tab" || event.isComposing || event.defaultPrevented) {
      return;
    }

    const content = this.#content;
    const trigger = this.#trigger;
    if (!content || !trigger) {
      return;
    }

    const forward = !event.shiftKey;
    const stops = tabStopsWithin(content);
    const edge = forward ? stops.at(-1) : stops[0];
    const active = document.activeElement;

    // Still moving between the float's own controls: the browser already does the right thing.
    // Focus resting on something that is not a stop at all counts as the edge, since a native
    // Tab has nothing further to reach from there either.
    if (
      active !== edge &&
      active instanceof HTMLElement &&
      stops.includes(active)
    ) {
      return;
    }

    // Backward lands on the trigger's LAST stop rather than the trigger element itself: on a
    // trigger that is not focusable in its own right (a typeahead, whose stop is the input it
    // wraps) focusing the wrapper would drop focus entirely.
    const target = forward
      ? adjacentTabStop(trigger, { forward: true, ignore: content })
      : (tabStopsWithin(trigger).at(-1) ?? trigger);

    event.preventDefault();

    // Focus BEFORE dismissing. Dismissal unmounts the content and would drop focus to `<body>`,
    // and it may settle asynchronously, so moving focus afterwards races the teardown instead of
    // replacing it.
    target?.focus();
    this.#close?.();
  }

  cleanup() {
    this.#content?.removeEventListener("keydown", this.handleContentKeydown);
    this.#boundTrigger?.removeEventListener(
      "keydown",
      this.handleTriggerKeydown,
      true
    );
  }
}
