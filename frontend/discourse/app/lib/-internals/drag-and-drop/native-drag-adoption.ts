import { cancel, next } from "@ember/runloop";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import {
  decorateExternalSource,
  type ExternalDragPayload,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import {
  ADOPTED_AS,
  ADOPTED_DRAG_TYPE,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";
import { makeArray } from "discourse/lib/helpers";

/** The one arg an adoption candidate is read for. */
export interface AdoptionCandidateArgs {
  adopts?: NativeDragAdoption | NativeDragAdoption[];
}

/**
 * Whether a drag was started by the browser and claimed by an adoption.
 *
 * @param data - The drag payload's `data`, as the underlying library carries it.
 */
export function isAdoptedDrag(data: Record<string, unknown> | undefined) {
  return data?.type === ADOPTED_DRAG_TYPE;
}

/**
 * Whether one of the supplied adoptions is the one that claimed this drag.
 *
 * @param data - The drag payload's `data`, as the underlying library carries it.
 * @param adopts - The target's `adopts` arg.
 */
export function offersAdoptionFor(
  data: Record<string, unknown> | undefined,
  adopts: NativeDragAdoption | NativeDragAdoption[] | undefined
) {
  return makeArray(adopts).some(
    (adoption) => adoption.type === data?.[ADOPTED_AS]
  );
}

/** What an adoption gate is asked about, and handed if it accepts. */
export interface NativeDragAdoptionFeedback {
  /** The element the browser chose to drag. */
  element: HTMLElement;

  /**
   * The incoming payload, already snapshotted. Not the live `DataTransfer`: its
   * handles go inert when the `dragstart` dispatch ends, so anything read later
   * would come back empty.
   */
  source: ExternalDragPayload;
}

/**
 * Opt-in description of a browser-started drag a target is willing to adopt.
 *
 * The gate is a predicate rather than a list of payload kinds because the kinds
 * are too coarse to be safe: a web link needs `"text"` accepted when a source
 * publishes its URL only as text, and that also describes a text selection.
 */
export interface NativeDragAdoption {
  /**
   * Names this kind of adopted drag: what `adopts` is matched against, what a
   * target reports as `source.type`, and what a monitor or auto-scroll filters
   * on. It travels beside the internal routing type, but downstream consumers
   * do not need to know that.
   */
  type: string;

  /** Whether this drag should be adopted. Throwing is treated as `false`. */
  match: (feedback: NativeDragAdoptionFeedback) => boolean;

  /** Payload for `source.data`; reserved routing keys are stamped over it. */
  getData?: (feedback: NativeDragAdoptionFeedback) => object;
}

/**
 * Live targets that might adopt, held so the listener below can ask them.
 *
 * Every target joins, not only those with `adopts`: deciding during registration
 * would read an argument inside the modifier's tracking frame and re-register
 * the drop target on unrelated argument changes. Reading `adopts` from a DOM
 * listener consumes nothing because no autotracking frame is open there.
 */
const adoptionCandidates = new Set<() => AdoptionCandidateArgs>();

let stopListeningForAdoption: (() => void) | null = null;

/** The one adoption a drag can have in flight, and how to undo it. */
let liveAdoption: { release: () => void } | null = null;

/**
 * Whether this drag started from a text selection, which must never be adopted.
 *
 * A selection drag can target a text node, which the `HTMLElement` check already
 * excludes, but some browsers report the nearest element instead. The selection
 * itself must therefore be checked as well as editable ancestry.
 */
function isTextSelectionDrag(target: HTMLElement) {
  if (target.closest("[contenteditable]:not([contenteditable='false'])")) {
    return true;
  }
  const selection = window.getSelection();
  return Boolean(
    selection &&
    !selection.isCollapsed &&
    selection.rangeCount > 0 &&
    selection.containsNode(target, true)
  );
}

/**
 * Reads and copies the payload while it is still available.
 *
 * String data is readable during `dragstart`; by `dragover` the store is in
 * protected mode, and item handles cannot be retained safely. The snapshot
 * therefore preserves strings and types while deliberately exposing an empty
 * `items` list instead of handing consumers dead objects.
 */
function snapshotPayload(dataTransfer: DataTransfer): ExternalDragPayload {
  const types = Array.from(dataTransfer.types);
  const strings = new Map<string, string>();
  for (const type of types) {
    if (type !== "Files") {
      strings.set(type, dataTransfer.getData(type));
    }
  }

  return decorateExternalSource({
    types,
    items: [],
    getStringData: (mediaType: string) => strings.get(mediaType) ?? null,
  } as Parameters<typeof decorateExternalSource>[0]);
}

/** The adoptions live targets currently offer, in registration order. */
function offeredAdoptions() {
  const offered: NativeDragAdoption[] = [];
  for (const getArgs of adoptionCandidates) {
    offered.push(...makeArray(getArgs().adopts));
  }
  return offered;
}

/**
 * Hands a browser-started drag to the element-drag adapter so ordinary targets
 * receive it.
 *
 * The adapter only dispatches for registered elements and looks one up while
 * `dragstart` bubbles. Registering from a capture-phase listener on `window`
 * lands in time for that same drag, giving registered sources and adopted page
 * content one dispatch path and one target lifecycle.
 */
function adoptNativeDrag(event: DragEvent) {
  const target = event.target;
  if (!(target instanceof HTMLElement) || !event.dataTransfer) {
    return;
  }

  // Already registered for element-drag dispatch. Registering over it would
  // replace the real source's entry, and releasing ours would delete theirs.
  if (target.closest("[data-drag-source]")) {
    return;
  }

  // Someone else's explicitly draggable element. Cleanup removes that attribute
  // unconditionally, so adopting it would strip one we did not add.
  if (target.hasAttribute("draggable")) {
    return;
  }

  if (isTextSelectionDrag(target)) {
    return;
  }

  const source = snapshotPayload(event.dataTransfer);
  if (source.containsFiles()) {
    return;
  }

  const feedback = { element: target, source };
  const adoption = offeredAdoptions().find((candidate) => {
    try {
      return candidate.match(feedback);
    } catch {
      // A consumer predicate must not decide the fate of later candidates or
      // surface as an unrelated failure from this app-wide listener.
      return false;
    }
  });

  if (!adoption) {
    return;
  }

  liveAdoption?.release();

  let started = false;
  let released = false;

  const cleanup = draggable({
    element: target,
    getInitialData: () => ({
      ...adoption.getData?.(feedback),
      // Last, so consumer data cannot overwrite the routing values and disguise
      // an adopted drag as a registered source.
      type: ADOPTED_DRAG_TYPE,
      [ADOPTED_AS]: adoption.type,
      native: source,
    }),
    // This fires synchronously during the originating dispatch. The drag-start
    // callback runs later and cannot distinguish a live drag from one that never
    // began.
    onGenerateDragPreview: () => {
      started = true;
    },
    onDrop: () => release(),
  });

  const release = () => {
    if (released) {
      return;
    }
    released = true;
    cancel(neverStarted);
    if (liveAdoption?.release === release) {
      liveAdoption = null;
    }
    // A registered source may have claimed this element since adoption. Cleanup
    // deletes registrations by element, so running ours would tear theirs down.
    if (!target.hasAttribute("data-drag-source")) {
      cleanup();
    }
  };

  // A drag can be cancelled before it starts, followed by no event that could
  // release this registration. A run-loop task waits until every listener had a
  // chance to start it; a microtask would run between listener invocations.
  const neverStarted = next(() => {
    if (!started) {
      release();
    }
  });

  liveAdoption = { release };
}

/** Test-only: releases adoption state and its global listener between tests. */
export function resetDragAdoptionForTesting() {
  liveAdoption?.release();
  liveAdoption = null;
  adoptionCandidates.clear();
  stopListeningForAdoption?.();
  stopListeningForAdoption = null;
}

export function watchForAdoptableDrags(
  getArgsRef: () => AdoptionCandidateArgs
) {
  adoptionCandidates.add(getArgsRef);
  if (!stopListeningForAdoption) {
    window.addEventListener("dragstart", adoptNativeDrag, { capture: true });
    stopListeningForAdoption = () =>
      window.removeEventListener("dragstart", adoptNativeDrag, {
        capture: true,
      });
  }

  return () => {
    adoptionCandidates.delete(getArgsRef);
    // An adoption already in flight belongs to its drag and must keep the
    // adapter registration until that drag ends.
    if (adoptionCandidates.size === 0) {
      stopListeningForAdoption?.();
      stopListeningForAdoption = null;
    }
  };
}
