import { cancel, schedule } from "@ember/runloop";
import { modifier } from "ember-modifier";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";

/**
 * Reports a float as positioned for the render path that has no positioning step: the mobile
 * modal, which the browser lays out itself instead of going through `updatePosition`.
 *
 * A positioned float fires `onPositioned` from `updatePosition`, once per placement. A modal has
 * no placement to compute and never repositions, so the equivalent moment is the render after it
 * is inserted — the first point at which its content has a size to measure. Scheduled on the
 * runloop so `settled()` covers it.
 */
export default modifier(
  (element: HTMLElement, [instance]: [FloatKitInstance]) => {
    const timer = schedule("afterRender", () =>
      instance.options.onPositioned?.(element)
    );

    return () => cancel(timer);
  }
);
