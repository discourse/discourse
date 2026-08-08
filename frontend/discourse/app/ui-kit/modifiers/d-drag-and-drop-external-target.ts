import {
  dropTargetForExternal,
  type ExternalDragPayload as NativeExternalDragPayload,
  type ExternalDropTargetEventBasePayload,
  type ExternalDropTargetGetFeedbackArgs,
} from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
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
import type {
  ExternalDragKind,
  ExternalDragPayload,
} from "discourse/services/drag-and-drop";
import {
  createEnterLeavePairing,
  type DropEffect,
  isDeepestTarget,
  toAcceptList,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

/** The pointer position as the underlying library reports it. */
type DragInput = ExternalDropTargetGetFeedbackArgs["input"];

/** The drag's initial, previous and current locations. */
type DragLocation = ExternalDropTargetEventBasePayload["location"];

/** What a synchronous gate (`canDrop`, `getDropEffect`) is asked about. */
export interface ExternalDropTargetFeedback {
  /** The incoming payload, with the read helpers bound to it. */
  source: ExternalDragPayload;

  /** Where the pointer is. */
  input: DragInput;

  /** This target's element. */
  element: Element;
}

/** What a lifecycle callback is told. */
export interface ExternalDropTargetEvent {
  /** The incoming payload, with the read helpers bound to it. */
  source: ExternalDragPayload;

  /** The drag's location history. */
  location: DragLocation;

  /** This target's element. */
  element: Element;
}

/**
 * State modifier class toggled on the target while a compatible
 * external drag is hovering. External drags don't carry a position
 * (they replace, they don't reorder), so a single class — not the
 * before/after/inside split the element variant uses — is enough.
 * Mirrors `--drag-*` from the element modifier so consumers can style
 * with a parallel selector set.
 */
const INDICATOR_CLASS = "--drag-over-external";

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

/**
 * Builds the decorated source object exposed to consumer callbacks.
 * Wraps PDND's raw payload (`{types, items, getStringData}`) with the
 * `contains*` / `get*` helpers bound to that payload, so the
 * consumer's call site reads `source.getFiles()` instead of
 * `getFiles({source})`. Keeps the library wall intact: PDND helpers
 * are imported here, not in plugin code.
 */
function decorateSource(
  payload: NativeExternalDragPayload
): ExternalDragPayload {
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

interface DDragAndDropExternalTargetSignature {
  /** The element to register as a drop target. */
  Element: HTMLElement;
  Args: {
    Named: {
      /**
       * Filters which external drag kinds engage the target. Omit to accept any
       * external drag.
       */
      accepts?: ExternalDragKind | ExternalDragKind[];

      /** Synchronous gate. Returning `false` refuses the drop. */
      canDrop?: (feedback: ExternalDropTargetFeedback) => boolean | void;

      /** Determines the cursor feedback browsers show during the drag. */
      getDropEffect?: (feedback: ExternalDropTargetFeedback) => DropEffect;

      /**
       * `false` to suppress the `--drag-over-external` indicator class. Defaults
       * to `true`.
       */
      indicator?: boolean;

      /** The cursor entered this target with a compatible external drag in flight. */
      onDragEnter?: (event: ExternalDropTargetEvent) => void;

      /**
       * The drag progressed. Throttled; fires when the input or the drop-target
       * hierarchy updates while this target is active.
       */
      onDrag?: (event: ExternalDropTargetEvent) => void;

      /** The cursor left this target. */
      onDragLeave?: (event: ExternalDropTargetEvent) => void;

      /** The drag was released on this target. */
      onDrop?: (event: ExternalDropTargetEvent) => void;
    };
    Positional: [];
  };
}

/**
 * The external drop target's named args, for a consumer driving
 * {@link registerDragAndDropExternalTarget} imperatively rather than through the
 * modifier.
 */
export type DragAndDropExternalTargetArgs =
  DDragAndDropExternalTargetSignature["Args"]["Named"];

/**
 * Imperative drop-target registration backed by Pragmatic Drag and
 * Drop's external adapter. Wraps `dropTargetForExternal` with the
 * deepest-target filter, the `--drag-over-external` indicator class,
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
 * @param element - The element to register as a drop target.
 * @param getArgsRef - Closure returning the latest args. PDND callbacks read
 *   this on every invocation, so arg changes take effect without re-registering.
 * @returns Cleanup function. Caller invokes it once on teardown (modifier
 *   destroy, component willDestroy, etc.).
 */
export function registerDragAndDropExternalTarget(
  element: Element,
  getArgsRef: () => DragAndDropExternalTargetArgs
) {
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
  const acceptsSource = (sourcePayload: NativeExternalDragPayload) => {
    const kinds = toAcceptList(getArgsRef().accepts);
    if (kinds.length === 0) {
      return true;
    }
    return kinds.some((kind) => {
      const handler = KIND_HANDLERS[kind];
      // Unknown kind names fail closed — better than silently matching.
      return handler ? handler.contains({ source: sourcePayload }) : false;
    });
  };

  const isDeepest = (location: DragLocation) =>
    isDeepestTarget(location, element);

  const pairing = createEnterLeavePairing();

  // See the note in `registerDragAndDropSource`.
  element.setAttribute("data-drop-target-external", "");

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
      // Ceasing to be the deepest target makes any indicator this element is
      // showing stale, and an ancestor is kept in the hierarchy rather than
      // sent a leave, so clearing here is the only chance to drop it.
      if (!isDeepest(location)) {
        clearIndicator();
        return;
      }
      const args = getArgsRef();
      if (args.indicator !== false) {
        showIndicator();
      }
      pairing.enter(() =>
        args.onDragEnter?.({
          source: decorateSource(source),
          location,
          element,
        })
      );
    },
    onDrag: ({ source, location }) => {
      if (!isDeepest(location)) {
        clearIndicator();
        return;
      }
      const args = getArgsRef();
      if (args.indicator !== false) {
        showIndicator();
      }
      // Taking over as the deepest target without a fresh enter; see the element
      // target, which pairs the same way.
      pairing.enter(() =>
        args.onDragEnter?.({
          source: decorateSource(source),
          location,
          element,
        })
      );
      args.onDrag?.({
        source: decorateSource(source),
        location,
        element,
      });
    },
    onDragLeave: ({ source, location }) => {
      clearIndicator();
      pairing.leave(() =>
        getArgsRef().onDragLeave?.({
          source: decorateSource(source),
          location,
          element,
        })
      );
    },
    onDrop: ({ source, location }) => {
      clearIndicator();
      pairing.reset();
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
    element.removeAttribute("data-drop-target-external");
  };
}

/**
 * Marks an element as a drop target for **external** drags — files,
 * URLs, HTML, text dragged into the window from outside (OS file
 * manager, another browser tab, etc.). Thin Ember-modifier wrapper
 * around {@link registerDragAndDropExternalTarget}. Every arg is documented on
 * {@link DragAndDropExternalTargetArgs}, and the payload every callback
 * receives on {@link ExternalDragPayload}.
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
 * Nested targets: only the deepest accepted target receives the
 * lifecycle callbacks, so an ancestor decorated with this modifier
 * doesn't double-handle a drop the child already claimed.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 *
 * @see Uppy's `DropTarget`, registered in `lib/uppy/uppy-upload.js` — dropping a FILE for UPLOAD goes through Uppy's
 *   `DropTarget` plugin, not through here. This modifier hands you the raw payload
 *   and stops; it will not upload anything.
 */
export default modifier<DDragAndDropExternalTargetSignature>(
  (element, _positional, args) =>
    // Pass `args` through to the closure WITHOUT reading any property of
    // it here. Reading args.X inside the body would mark its tag consumed
    // and force the modifier to re-run (re-registering PDND) on every
    // change. The closure reads fresh values inside PDND's callbacks.
    registerDragAndDropExternalTarget(element, () => args)
);
