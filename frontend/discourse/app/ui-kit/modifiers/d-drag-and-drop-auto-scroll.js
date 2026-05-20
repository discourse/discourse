// @ts-check
import { registerDestructor } from "@ember/destroyable";
import {
  autoScrollForElements,
  autoScrollWindowForElements,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/element";
import Modifier from "ember-modifier";

/**
 * Imperative auto-scroll registration backed by Pragmatic Drag and
 * Drop. Wraps `autoScrollForElements` (element-scoped) and
 * `autoScrollWindowForElements` (window-scoped) behind one shape.
 *
 * Use this when you can't attach the `{{dDragAndDropAutoScroll}}`
 * modifier — e.g. setting up window auto-scroll without anchoring to
 * a specific element in your template. The modifier class is a thin
 * wrapper around this function for the template-based common case.
 *
 * Library-agnostic by design: PDND auto-scroll is imported only here.
 *
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation. Args shape:
 *   `types` (string | string[] | undefined), `axis`
 *   (`"vertical"` / `"horizontal"` / `"all"`), `target`
 *   (`"element"` | `"window"`), `element` (required when
 *   `target === "element"`).
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown.
 */
export function registerAutoScroll(getArgsRef) {
  const matchesType = ({ source }) => {
    const types = getArgsRef().types;
    const list = Array.isArray(types) ? types : types ? [types] : [];
    if (list.length === 0) {
      return true;
    }
    return list.includes(source.data?.type);
  };

  const getAllowedAxis = () => getArgsRef().axis ?? "vertical";

  const args = getArgsRef();
  if (args.target === "window") {
    return autoScrollWindowForElements({
      canScroll: matchesType,
      getAllowedAxis,
    });
  }
  return autoScrollForElements({
    element: args.element,
    canScroll: matchesType,
    getAllowedAxis,
  });
}

/**
 * Enables PDND auto-scroll while a compatible drag is in flight.
 * Thin Ember-modifier wrapper around {@link registerAutoScroll}.
 *
 * Attach to a scroll container to auto-scroll that container when
 * the cursor approaches its edges:
 *
 * ```hbs
 * <div class="canvas"
 *   {{dDragAndDropAutoScroll types=(array "ve-block") axis="vertical"}}
 * >
 * ```
 *
 * Attach to a sentinel inside the editor root with `target="window"`
 * to auto-scroll the document body / window instead:
 *
 * ```hbs
 * <span class="visually-hidden"
 *   {{dDragAndDropAutoScroll target="window" types=this.acceptedTypes}}
 * ></span>
 * ```
 *
 * Args (named):
 *  - `types` — string or array of strings. Only drags whose source
 *    `type` matches engage the auto-scroll. Omit to engage on any
 *    drag (rare).
 *  - `axis` — `"vertical"` (default) / `"horizontal"` / `"all"`.
 *  - `target` — `"element"` (default — scroll the host element)
 *    or `"window"` (scroll the window; element is ignored).
 */
export default class DDragAndDropAutoScrollModifier extends Modifier {
  #cleanup = null;
  #args = {};

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(element, _positional, args = {}) {
    const { types, axis = "vertical", target = "element" } = args;
    this.#args = { types, axis, target, element };
    if (!this.#cleanup) {
      this.#cleanup = registerAutoScroll(() => this.#args);
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
  }
}
