import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import Modifier, { type ArgsFor } from "ember-modifier";
import {
  type ScrollAxis,
  ScrollEdgesWatcher,
} from "discourse/ui-kit/-internals/scroll-strip/edges";

interface DScrollEdgesSignature {
  /** The scroll container being observed. */
  Element: HTMLElement;
  Args: {
    Named: {
      /** The scroll axis to report on. Defaults to `"horizontal"`. */
      axis?: ScrollAxis;
    };
    Positional: [];
  };
}

/**
 * Stamps a scroll container's overflow state onto it as data attributes, so
 * a stylesheet can hint at content beyond an edge without any of the
 * measuring living in CSS:
 *
 * - `data-d-scroll-axis`, the axis being reported;
 * - `data-d-scroll-overflow` while the content is larger than the container;
 * - `data-d-scroll-at-start` while it rests on its start edge;
 * - `data-d-scroll-at-end` while it rests on its end edge.
 *
 * The state follows scrolling, the container resizing, children coming and
 * going, and children changing size, which covers a web font swapping in
 * after first paint. Offsets are read as magnitudes, so a right-to-left
 * container reports the same logical edges. An axis the container's
 * computed overflow does not let it scroll on is never reported as
 * overflowing.
 */
export default class DScrollEdgesModifier extends Modifier<DScrollEdgesSignature> {
  #element: HTMLElement | null = null;
  #axis: ScrollAxis | null = null;
  #watcher: ScrollEdgesWatcher | null = null;

  constructor(owner: Owner, args: ArgsFor<DScrollEdgesSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#teardown());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    { axis = "horizontal" }: DScrollEdgesSignature["Args"]["Named"]
  ) {
    if (this.#element !== element || this.#axis !== axis) {
      this.#teardown();
      this.#element = element;
      this.#axis = axis;
      this.#watcher = new ScrollEdgesWatcher(element, { axis });
      return;
    }

    this.#watcher?.refresh();
  }

  #teardown() {
    this.#watcher?.disconnect();
    this.#watcher = null;
    this.#element = null;
    this.#axis = null;
  }
}
