// @ts-check
import { registerDestructor } from "@ember/destroyable";
import {
  autoScrollForElements,
  autoScrollWindowForElements,
} from "@atlaskit/pragmatic-drag-and-drop-auto-scroll/element";
import Modifier from "ember-modifier";

/**
 * Enables PDND auto-scroll while a compatible drag is in flight.
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
 *
 * Wraps `autoScrollForElements` / `autoScrollWindowForElements` from
 * `@atlaskit/pragmatic-drag-and-drop-auto-scroll/element`. The cleanup
 * function returned by PDND is invoked on modifier teardown so the
 * scroll engagement detaches with the host component.
 */
export default class DDragAndDropAutoScrollModifier extends Modifier {
  #cleanup = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    element,
    _positional,
    { types, axis = "vertical", target = "element" } = {}
  ) {
    this.#detach();

    const acceptList = Array.isArray(types) ? types : types ? [types] : [];
    const matchesType = ({ source }) => {
      if (acceptList.length === 0) {
        return true;
      }
      return acceptList.includes(source.data?.type);
    };

    if (target === "window") {
      this.#cleanup = autoScrollWindowForElements({
        canScroll: matchesType,
        getAllowedAxis: () => axis,
      });
    } else {
      this.#cleanup = autoScrollForElements({
        element,
        canScroll: matchesType,
        getAllowedAxis: () => axis,
      });
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
  }
}
