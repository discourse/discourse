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
 * The float is treated as one logical segment beside the trigger. Every Tab within the segment is
 * handled from a freshly computed local sequence, so dynamic controls, radio groups, and positive
 * tabindex values cannot make the browser and the edge check disagree.
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
  #departing = false;
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
    // CAPTURE phase, because a control inside the trigger may stop Tab from bubbling. When the
    // panel has a stop, inline ordering is authoritative and intentionally precedes consumer
    // bubbling handlers. With no panel stop, the event continues untouched.
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
      event.defaultPrevented ||
      this.#departing
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
    if (!lastTriggerStop || document.activeElement !== lastTriggerStop) {
      return;
    }

    const contentStops = tabStopsWithin(content);
    if (!contentStops.length) {
      return;
    }

    event.preventDefault();
    contentStops[0].focus();
  }

  /** Moves within the float's logical segment, or leaves it from the trigger's page position. */
  @bind
  handleContentKeydown(event: KeyboardEvent) {
    if (
      event.key !== "Tab" ||
      event.isComposing ||
      event.defaultPrevented ||
      this.#departing
    ) {
      return;
    }

    const content = this.#content;
    const trigger = this.#trigger;
    if (!content || !trigger) {
      return;
    }

    const forward = !event.shiftKey;
    const active = document.activeElement;
    if (!(active instanceof HTMLElement)) {
      return;
    }

    const internalTarget = adjacentTabStop(active, { forward, root: content });
    if (internalTarget) {
      event.preventDefault();
      internalTarget.focus();
      return;
    }

    const triggerAnchor = tabStopsWithin(trigger).at(-1);
    const target = forward
      ? triggerAnchor &&
        adjacentTabStop(triggerAnchor, { forward: true, ignore: content })
      : triggerAnchor;

    this.#departing = true;
    if (target) {
      event.preventDefault();
    }

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
