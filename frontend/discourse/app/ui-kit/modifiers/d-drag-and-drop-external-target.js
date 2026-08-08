// @ts-check
import { dropTargetForExternal } from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
import {
  containsFiles,
  getFiles,
} from "@atlaskit/pragmatic-drag-and-drop/external/file";
import {
  containsHTML,
  getHTML,
} from "@atlaskit/pragmatic-drag-and-drop/external/html";
import {
  containsText,
  getText,
} from "@atlaskit/pragmatic-drag-and-drop/external/text";
import {
  containsURLs,
  getURLs,
} from "@atlaskit/pragmatic-drag-and-drop/external/url";
import { modifier } from "ember-modifier";

/**
 * BEM-style indicator class toggled on the target while a compatible
 * external drag is hovering. External drags don't carry a position
 * (they replace, they don't reorder), so a single class — not the
 * before/after/inside split the element variant uses — is enough.
 * Mirrors `is-drag-*` from the element modifier so consumers can style
 * with a parallel selector set.
 */
const INDICATOR_CLASS = "is-drag-over-external";

/**
 * Vocabulary the modifier accepts under its `accepts` arg. Each key
 * maps to PDND's matching predicate / extractor pair so consumers
 * never import from `@atlaskit/pragmatic-drag-and-drop` themselves.
 */
const KIND_HANDLERS = Object.freeze({
  files: { contains: containsFiles, get: getFiles },
  html: { contains: containsHTML, get: getHTML },
  text: { contains: containsText, get: getText },
  urls: { contains: containsURLs, get: getURLs },
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

/**
 * Builds the decorated source object exposed to consumer callbacks.
 * Wraps PDND's raw payload (`{types, items, getStringData}`) with the
 * `contains*` / `get*` helpers bound to that payload, so the
 * consumer's call site reads `source.getFiles()` instead of
 * `getFiles({source})`. Keeps the library wall intact: PDND helpers
 * are imported here, not in plugin code.
 *
 * @param {{types: string[], items: DataTransferItem[], getStringData: (mediaType: string) => string}} payload
 */
function decorateSource(payload) {
  return {
    types: payload.types,
    items: payload.items,
    getStringData: (mediaType) => payload.getStringData(mediaType),
    containsFiles: () => containsFiles({ source: payload }),
    getFiles: () => getFiles({ source: payload }),
    containsHTML: () => containsHTML({ source: payload }),
    getHTML: () => getHTML({ source: payload }),
    containsText: () => containsText({ source: payload }),
    getText: () => getText({ source: payload }),
    containsURLs: () => containsURLs({ source: payload }),
    getURLs: () => getURLs({ source: payload }),
  };
}

/**
 * Imperative drop-target registration backed by Pragmatic Drag and
 * Drop's external adapter. Wraps `dropTargetForExternal` with the
 * deepest-target filter, the `is-drag-over-external` indicator class,
 * and the decorated-source payload the modifier exposes.
 *
 * Use this directly when you've captured an element ref outside your
 * own template (e.g. via `didInsert` on a sibling marker, or after
 * walking the DOM) and can't attach the `{{dDragAndDropExternalTarget}}`
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
 *   `accepts` (string | string[] | undefined), `canDrop`,
 *   `getDropEffect`, `onDragEnter`, `onDrag`, `onDragLeave`, `onDrop`,
 *   `indicator`.
 * @returns {() => void} Cleanup function. Caller invokes it once on
 *   teardown (modifier destroy, component willDestroy, etc.).
 */
export function registerDragAndDropExternalTarget(element, getArgsRef) {
  let isIndicating = false;

  const showIndicator = () => {
    if (isIndicating) {
      return;
    }
    element.classList.add(INDICATOR_CLASS);
    isIndicating = true;
  };

  const clearIndicator = () => {
    if (!isIndicating) {
      return;
    }
    element.classList.remove(INDICATOR_CLASS);
    isIndicating = false;
  };

  /**
   * Resolves the `accepts` arg against the raw PDND source payload.
   * Empty / missing `accepts` accepts every external drag, mirroring
   * the element variant's "no filter = accept all" behaviour.
   */
  const acceptsSource = (sourcePayload) => {
    const kinds = normaliseAccepts(getArgsRef().accepts);
    if (kinds.length === 0) {
      return true;
    }
    return kinds.some((kind) => {
      const handler = KIND_HANDLERS[kind];
      // Unknown kind names fail closed — better than silently matching.
      return handler ? handler.contains({ source: sourcePayload }) : false;
    });
  };

  // PDND fires lifecycle events on every active drop target in the
  // hierarchy. The contract here is "deepest accepted target wins":
  // short-circuit every callback unless this element is at the top of
  // the `dropTargets` bubble stack.
  const isDeepest = (location) =>
    location.current.dropTargets[0]?.element === element;

  const cleanup = dropTargetForExternal({
    element,
    canDrop: ({ source, input }) => {
      if (!acceptsSource(source)) {
        return false;
      }
      const args = getArgsRef();
      if (!args.canDrop) {
        return true;
      }
      return (
        args.canDrop({
          source: decorateSource(source),
          input,
          element,
        }) !== false
      );
    },
    getDropEffect: ({ source, input }) => {
      const args = getArgsRef();
      return args.getDropEffect?.({
        source: decorateSource(source),
        input,
        element,
      });
    },
    onDragEnter: ({ source, location }) => {
      if (!isDeepest(location)) {
        return;
      }
      const args = getArgsRef();
      if (args.indicator !== false) {
        showIndicator();
      }
      args.onDragEnter?.({
        source: decorateSource(source),
        location,
        element,
      });
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        return;
      }
      getArgsRef().onDrag?.({
        source: decorateSource(source),
        location,
        element,
      });
    },
    onDragLeave: ({ source, location }) => {
      clearIndicator();
      getArgsRef().onDragLeave?.({
        source: decorateSource(source),
        location,
        element,
      });
    },
    onDrop: ({ source, location }) => {
      clearIndicator();
      if (!isDeepest(location)) {
        return;
      }
      getArgsRef().onDrop?.({
        source: decorateSource(source),
        location,
        element,
      });
    },
  });

  return () => {
    cleanup();
    clearIndicator();
  };
}

/**
 * Marks an element as a drop target for **external** drags — files,
 * URLs, HTML, text dragged into the window from outside (OS file
 * manager, another browser tab, etc.). Thin Ember-modifier wrapper
 * around {@link registerDragAndDropExternalTarget}.
 *
 * Pair with the existing `dDragAndDropTarget` modifier for
 * element-to-element drags; the two adapters are independent and can
 * coexist on the same element. The external adapter does not call
 * `preventDefault`, so it also coexists with libraries that want to
 * consume the same native `dragover` / `drop` events (e.g. Uppy's
 * `@uppy/drop-target` plugin).
 *
 * Files:
 *
 * ```hbs
 * <div {{dDragAndDropExternalTarget
 *   accepts="files"
 *   onDrop=this.handleFileDrop
 * }}>...</div>
 * ```
 *
 * Multiple kinds:
 *
 * ```hbs
 * <div {{dDragAndDropExternalTarget
 *   accepts=(array "files" "urls")
 *   onDragEnter=this.highlight
 *   onDragLeave=this.unhighlight
 *   onDrop=this.handleDrop
 * }}>...</div>
 * ```
 *
 * Args (named):
 *  - `accepts` — `"files"` | `"html"` | `"text"` | `"urls"` or an
 *    array of those keys. Filters which external drag kinds engage
 *    the target. Omit to accept any external drag.
 *  - `canDrop` — `({source, input, element}) => boolean`. Synchronous
 *    gate. `source` is the decorated payload (see below).
 *  - `getDropEffect` — `({source, input, element}) => "copy" | "move"
 *    | "link"`. Determines the cursor feedback browsers show during
 *    the drag.
 *  - `indicator` — `false` to suppress the `is-drag-over-external`
 *    indicator class toggling (defaults to `true`).
 *  - `onDragEnter` / `onDrag` / `onDragLeave` / `onDrop` —
 *    `({source, location, element}) => void`. `onDrag` is PDND's
 *    throttled drag-progress event; it fires when the input or the
 *    drop-target hierarchy updates while this target is active.
 *
 * Decorated source shape (passed into every callback):
 *
 * ```
 * {
 *   types,           // string[] of native MIME types incl. "Files"
 *   items,           // DataTransferItem[]
 *   getStringData,   // (mediaType) => string | null
 *   containsFiles(), getFiles(),     // File[]
 *   containsHTML(),  getHTML(),      // string | null
 *   containsText(),  getText(),      // string | null
 *   containsURLs(),  getURLs(),      // string[]
 * }
 * ```
 *
 * Nested targets: only the deepest accepted target receives the
 * lifecycle callbacks, so an ancestor decorated with this modifier
 * doesn't double-handle a drop the child already claimed.
 */
export default modifier((element, _positional, args) =>
  // Pass `args` through to the closure WITHOUT reading any property of
  // it here. Reading args.X inside the body would mark its tag consumed
  // and force the modifier to re-run (re-registering PDND) on every
  // change. The closure reads fresh values inside PDND's callbacks.
  registerDragAndDropExternalTarget(element, () => args)
);
