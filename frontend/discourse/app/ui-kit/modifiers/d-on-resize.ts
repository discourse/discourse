import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel, throttle } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";

interface DOnResizeOptions {
  /** Throttle interval in ms. Defaults to `0`. */
  delay?: number;
  /** Whether to also invoke on the leading edge. Defaults to `false`. */
  immediate?: boolean;
}

type DOnResizeCallback = (entries: ResizeObserverEntry[]) => void;

interface DOnResizeSignature {
  Element: Element;
  Args: {
    Positional: [callback: DOnResizeCallback, options?: DOnResizeOptions];
  };
}

/**
 * Calls `callback` with the observed `ResizeObserverEntry`s whenever the element
 * resizes, throttled through the runloop. Cleans up the observer on teardown.
 */
export default class DOnResize extends Modifier<DOnResizeSignature> {
  #resizeObserver?: ResizeObserver;
  #throttleHandler?: ReturnType<typeof throttle>;

  constructor(owner: Owner, args: ArgsFor<DOnResizeSignature>) {
    super(owner, args);
    registerDestructor(this, () => this.#cleanup());
  }

  modify(
    element: Element,
    [fn, options = {}]: DOnResizeSignature["Args"]["Positional"]
  ) {
    this.#resizeObserver = new ResizeObserver((entries) => {
      this.#throttleHandler = throttle(
        this,
        fn,
        entries,
        options.delay ?? 0,
        options.immediate ?? false
      );
    });

    this.#resizeObserver.observe(element);
  }

  #cleanup() {
    cancel(this.#throttleHandler);
    this.#resizeObserver?.disconnect();
  }
}
