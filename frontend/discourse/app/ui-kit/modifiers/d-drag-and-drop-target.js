// @ts-check
import { dropTargetForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { modifier } from "ember-modifier";

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

function normaliseAccepts(accepts) {
  if (!accepts) {
    return [];
  }
  if (Array.isArray(accepts)) {
    return accepts;
  }
  return [accepts];
}

function sourceFromPDND(pdndSource, element) {
  return {
    type: pdndSource.data?.type ?? null,
    data: pdndSource.data ?? {},
    element: pdndSource.element ?? element ?? null,
  };
}

/**
 * Imperative drop-target registration backed by Pragmatic Drag and
 * Drop. Wraps `dropTargetForElements` with the deepest-target filter,
 * `is-drag-above` / `is-drag-below` indicator classes, and the
 * source-payload normalisation the modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropTarget}}`
 * modifier. The modifier itself is a thin wrapper around this
 * function for the template-based common case.
 *
 * Library-agnostic by design: `@atlaskit/pragmatic-drag-and-drop` is
 * imported only by the ui-kit modifier files. Consumers (plugins,
 * core features) talk to this helper, not to PDND directly.
 *
 * @param {Element} element - The element to register as a drop target.
 * @param {() => Object} getArgsRef - Closure returning the latest args.
 *   PDND callbacks read this on every invocation, so arg changes take
 *   effect without re-registering. Args shape matches the modifier:
 *   `accepts` (string | string[] | undefined), `position`, `axis`,
 *   `canDrop`, `getData`, `getDropEffect`, `getIsSticky`,
 *   `onDragEnter`, `onDrag`, `onDragLeave`, `onDrop`, `indicator`.
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown (modifier destroy, component willDestroy, etc.).
 */
export function registerDragAndDropTarget(element, getArgsRef) {
  let activeClass = null;

  const applyIndicator = (position, axis) => {
    const className = POSITION_CLASSES[position]?.[axis];
    if (!className || activeClass === className) {
      return;
    }
    if (activeClass) {
      element.classList.remove(activeClass);
    }
    element.classList.add(className);
    activeClass = className;
  };

  const clearIndicators = () => {
    if (activeClass) {
      element.classList.remove(activeClass);
      activeClass = null;
    }
  };

  const acceptsType = (type) => {
    const list = normaliseAccepts(getArgsRef().accepts);
    return list.length === 0 || list.includes(type);
  };

  const resolvePosition = (input) => {
    const args = getArgsRef();
    if (args.position) {
      return args.position;
    }
    const axis = args.axis ?? "y";
    const rect = element.getBoundingClientRect();
    if (axis === "x") {
      return input.clientX < rect.left + rect.width / 2 ? "before" : "after";
    }
    return input.clientY < rect.top + rect.height / 2 ? "before" : "after";
  };

  // PDND fires lifecycle events on every active drop target in the
  // hierarchy. The contract here is "deepest accepted target wins":
  // short-circuit on every callback unless this element is at the top
  // of the `dropTargets` bubble stack.
  const isDeepest = (location) =>
    location.current.dropTargets[0]?.element === element;

  const cleanup = dropTargetForElements({
    element,
    canDrop: ({ source, input }) => {
      if (!acceptsType(source.data?.type)) {
        return false;
      }
      const args = getArgsRef();
      if (!args.canDrop) {
        return true;
      }
      return (
        args.canDrop({
          source: sourceFromPDND(source, element),
          input,
          element,
        }) !== false
      );
    },
    getData: () => getArgsRef().getData?.() ?? {},
    getDropEffect: ({ source, input }) => {
      const args = getArgsRef();
      return args.getDropEffect?.({
        source: sourceFromPDND(source, element),
        input,
        element,
      });
    },
    getIsSticky: () => getArgsRef().getIsSticky?.() === true,
    onDragEnter: ({ source, location }) => {
      if (!isDeepest(location)) {
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        applyIndicator(pos, args.axis ?? "y");
      }
      args.onDragEnter?.({
        source: sourceFromPDND(source, element),
        position: pos,
        location,
        element,
      });
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        return;
      }
      const args = getArgsRef();
      const pos = resolvePosition(location.current.input);
      if (args.indicator !== false) {
        applyIndicator(pos, args.axis ?? "y");
      }
      args.onDrag?.({
        source: sourceFromPDND(source, element),
        position: pos,
        location,
        element,
      });
    },
    onDragLeave: ({ source, location }) => {
      clearIndicators();
      getArgsRef().onDragLeave?.({
        source: sourceFromPDND(source, element),
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
      clearIndicators();
      getArgsRef().onDrop?.({
        source: sourceFromPDND(source, element),
        position: pos,
        location,
        element,
      });
    },
  });

  return () => {
    cleanup();
    clearIndicators();
  };
}

/**
 * Marks an element as a drop target compatible with the
 * `dDragAndDropSource` vocabulary. Thin Ember-modifier wrapper around
 * {@link registerDragAndDropTarget}.
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
 *   accepts="block"
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
 *  - `canDrop` — `({source, input, element}) => boolean`. Synchronous
 *    gate. Source is `{type, data, element}` — the shape the matching
 *    `dDragAndDropSource` published.
 *  - `getData` — `() => object`. Optional target-side metadata that
 *    PDND attaches to its `DropTargetRecord`; consumers reading
 *    `source.dropTargets` see it under `.data`.
 *  - `getDropEffect` — `({source, input, element}) => "copy" | "move"
 *    | "link"`. Determines the cursor feedback browsers show.
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
 * Nested targets: only the deepest accepted target receives the
 * lifecycle callbacks, so an ancestor decorated with this modifier
 * doesn't double-handle a drop the child already claimed.
 *
 * Testing: in JS integration tests use `simulateDrag` from
 * `discourse/tests/helpers/ui-kit/drag-and-drop-helper`; in Ruby system
 * tests use `SystemHelpers#drag_and_drop` (a real native drag via
 * Playwright) rather than Capybara's `drag_to`, whose synthetic mouse
 * events can silently stall mid-drag.
 */
export default modifier((element, _positional, args) =>
  // Pass `args` through to the closure WITHOUT reading any property of
  // it here. Reading args.X inside the body would mark its tag consumed
  // and force the modifier to re-run (re-registering PDND) on every
  // change. The closure reads fresh values inside PDND's callbacks.
  registerDragAndDropTarget(element, () => args)
);
