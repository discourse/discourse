// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { dropTargetForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import Modifier from "ember-modifier";

/**
 * Per-axis CSS class names toggled while the cursor is hovering with a
 * compatible drag in flight. Mirrored in the foundation styles at
 * `app/assets/stylesheets/common/foundation/draggable.scss` so consumers
 * get a 2px tertiary indicator above/below the row by default and can
 * override with their own treatment when a different look is needed.
 */
const POSITION_CLASSES = Object.freeze({
  before: { y: "is-drag-above", x: "is-drag-left" },
  after: { y: "is-drag-below", x: "is-drag-right" },
  inside: { y: "is-drag-inside", x: "is-drag-inside" },
});

/**
 * Marks an element as a drop target compatible with the
 * `dDragAndDropSource` vocabulary. Backed by Pragmatic Drag and Drop's
 * `dropTargetForElements` — events are rAF-batched, the modifier
 * doesn't need to track enter-depth or debounce dragleave flicker
 * by hand.
 *
 * Smart row mode — position is computed from the cursor against the
 * element's midpoint:
 *
 * ```hbs
 * <li {{dDragAndDropTarget
 *   accepts="sidebar-link"
 *   onDrop=this.reorder
 * }}>...</li>
 * ```
 *
 * Fixed-position mode — for explicit `"before"` / `"after"` / `"inside"`
 * zones where the slot is decided by geometry, not the cursor:
 *
 * ```hbs
 * <div {{dDragAndDropTarget
 *   accepts="ve-block"
 *   position="inside"
 *   onDrop=this.applyMove
 * }}></div>
 * ```
 *
 * Args (named):
 *  - `accepts` — string or array of strings. The dragged source's
 *    `type` must be in this list for the target to engage. Omit to
 *    accept any source.
 *  - `position` — fixed `"before"` / `"after"` / `"inside"`. When set,
 *    `axis` and the midpoint logic are ignored.
 *  - `axis` — `"y"` (default) or `"x"`. Drives the indicator class
 *    selection and the smart-row position math.
 *  - `canDrop` — `({source, input}) => boolean`. Synchronous gate.
 *    Source is `{type, data, element}` — the shape the matching
 *    `dDragAndDropSource` published.
 *  - `getData` — `() => object`. Optional target-side metadata that
 *    PDND attaches to its `DropTargetRecord`; consumers reading
 *    `source.dropTargets` see it under `.data`.
 *  - `getDropEffect` — `({source, input}) => "copy" | "move" | "link"`.
 *    Determines the cursor feedback browsers show.
 *  - `getIsSticky` — `() => boolean`. Enables PDND's sticky-target
 *    semantics (the target stays "current" briefly after the cursor
 *    leaves, useful for hover-to-expand patterns).
 *  - `indicator` — `false` to suppress the `is-drag-*` indicator
 *    class toggling (defaults to `true`).
 *  - `onDragEnter` / `onDrag` / `onDragLeave` / `onDrop` —
 *    `({source, position, location, element}) => void`. `onDrag` is
 *    PDND's throttled drag-progress event; it fires when the input
 *    or the drop-target hierarchy updates while this target is
 *    active.
 *
 * Nested targets: PDND walks the DOM and only reports the *deepest*
 * accepted target in `location.current.dropTargets[0]`, so an ancestor
 * decorated with this modifier doesn't double-handle a drop the child
 * already claimed.
 */
export default class DDragAndDropTargetModifier extends Modifier {
  #cleanup = null;
  #element = null;
  #activeClass = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    element,
    _positional,
    {
      accepts,
      position,
      axis = "y",
      canDrop,
      getData,
      getDropEffect,
      getIsSticky,
      onDragEnter,
      onDrag,
      onDragLeave,
      onDrop,
      indicator = true,
    } = {}
  ) {
    if (this.#element && this.#element !== element) {
      this.#detach();
    }
    this.#element = element;
    this.#detach();

    const acceptList = this.#normaliseAccepts(accepts);
    const acceptsType = (type) =>
      acceptList.length === 0 || acceptList.includes(type);

    const resolvePosition = (input) => {
      if (position) {
        return position;
      }
      const rect = element.getBoundingClientRect();
      if (axis === "x") {
        return input.clientX < rect.left + rect.width / 2 ? "before" : "after";
      }
      return input.clientY < rect.top + rect.height / 2 ? "before" : "after";
    };

    const sourceFromPDND = (pdndSource) => ({
      type: pdndSource.data?.type ?? null,
      data: pdndSource.data ?? {},
      element: pdndSource.element ?? null,
    });

    // PDND fires lifecycle events on every active drop target in the
    // hierarchy. The old ui-kit contract was "deepest accepted target
    // wins" — match that here by short-circuiting on every callback
    // except when this element is at the top of the `dropTargets`
    // bubble stack.
    const isDeepest = (location) =>
      location.current.dropTargets[0]?.element === element;

    this.#cleanup = dropTargetForElements({
      element,
      canDrop: ({ source, input }) => {
        if (!acceptsType(source.data?.type)) {
          return false;
        }
        if (!canDrop) {
          return true;
        }
        return (
          canDrop({ source: sourceFromPDND(source), input, element }) !== false
        );
      },
      getData: getData ? () => getData() : undefined,
      getDropEffect: getDropEffect
        ? ({ source, input }) =>
            getDropEffect({ source: sourceFromPDND(source), input, element })
        : undefined,
      getIsSticky: getIsSticky ? () => getIsSticky() === true : undefined,
      onDragEnter: ({ source, location }) => {
        if (!isDeepest(location)) {
          return;
        }
        const pos = resolvePosition(location.current.input);
        if (indicator) {
          this.#applyIndicator(pos, axis);
        }
        onDragEnter?.({
          source: sourceFromPDND(source),
          position: pos,
          location,
          element,
        });
      },
      onDrag: ({ source, location }) => {
        if (!isDeepest(location)) {
          return;
        }
        const pos = resolvePosition(location.current.input);
        if (indicator) {
          this.#applyIndicator(pos, axis);
        }
        onDrag?.({
          source: sourceFromPDND(source),
          position: pos,
          location,
          element,
        });
      },
      onDragLeave: ({ source, location }) => {
        this.#clearIndicators();
        onDragLeave?.({
          source: sourceFromPDND(source),
          position: null,
          location,
          element,
        });
      },
      onDrop: ({ source, location }) => {
        if (!isDeepest(location)) {
          return;
        }
        const pos = resolvePosition(location.current.input);
        this.#clearIndicators();
        onDrop?.({
          source: sourceFromPDND(source),
          position: pos,
          location,
          element,
        });
      },
    });
  }

  #normaliseAccepts(accepts) {
    if (!accepts) {
      return [];
    }
    if (Array.isArray(accepts)) {
      return accepts;
    }
    return [accepts];
  }

  #applyIndicator(position, axis) {
    const className = POSITION_CLASSES[position]?.[axis];
    if (!className) {
      return;
    }
    if (this.#activeClass === className) {
      return;
    }
    if (this.#activeClass) {
      this.#element.classList.remove(this.#activeClass);
    }
    this.#element.classList.add(className);
    this.#activeClass = className;
  }

  #clearIndicators() {
    if (this.#activeClass) {
      this.#element.classList.remove(this.#activeClass);
      this.#activeClass = null;
    }
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#clearIndicators();
  }
}
