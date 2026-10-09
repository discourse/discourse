import { cancel, next } from "@ember/runloop";
import { draggable } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { consumerMayThrow } from "discourse/lib/-internals/drag-and-drop/consumer-may-throw";
import {
  decorateExternalSource,
  type ExternalDragPayload,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import {
  ADOPTED_AS,
  ADOPTED_DRAG_TYPE,
  DRAG_BODY,
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
   * The incoming payload, already snapshotted. It is not the live
   * `DataTransfer`. Those handles go inert when the `dragstart` dispatch ends,
   * so a later read comes back empty.
   */
  source: ExternalDragPayload;
}

/**
 * Opt-in description of a browser-started drag a target is willing to adopt.
 *
 * The gate is a predicate rather than a list of payload kinds, because the
 * kinds are too coarse. Accepting `"text"` catches a URL published only as
 * text, but it catches a dragged text selection too.
 */
export interface NativeDragAdoption {
  /**
   * Names this kind of adopted drag. `adopts` is matched against it, a target
   * reports it as `source.type`, and a monitor or auto-scroll filters on it.
   */
  type: string;

  /** Whether this drag should be adopted. Throwing is reported as a refusal. */
  match: (feedback: NativeDragAdoptionFeedback) => boolean;

  /**
   * Payload for `source.data`. Reserved routing keys are stamped over it.
   * Throwing is reported and yields no payload.
   */
  getData?: (feedback: NativeDragAdoptionFeedback) => object;
}

/**
 * Live targets that might adopt, held so the listener below can ask them.
 *
 * Every target joins, not only those with `adopts`. Reading the arg during
 * registration would track it and re-register the target on unrelated changes.
 * A DOM listener has no tracking frame open, so reading it there is free.
 */
const adoptionCandidates = new Set<() => AdoptionCandidateArgs>();

let stopListeningForAdoption: (() => void) | null = null;

/** The one adoption a drag can have in flight, and how to undo it. */
let liveAdoption: { release: () => void } | null = null;

/**
 * Whether this drag started from a text selection, which must never be adopted.
 *
 * A selection drag can target a text node, which the `HTMLElement` check
 * already excludes, but some browsers report the nearest element instead. So
 * editable ancestry, text controls and the document selection are all asked.
 */
function isTextSelectionDrag(target: HTMLElement) {
  if (target.closest("[contenteditable]:not([contenteditable='false'])")) {
    return true;
  }
  // A text control keeps its selection out of the document's, so the check
  // below cannot see it. Ask the control itself, and refuse when it will not
  // answer: some control types report null offsets rather than a range.
  if (
    (target instanceof HTMLInputElement ||
      target instanceof HTMLTextAreaElement) &&
    (target.selectionStart === null ||
      target.selectionStart !== target.selectionEnd)
  ) {
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
 * String data is readable during `dragstart`. By `dragover` the store is
 * protected and item handles cannot be held safely. So the snapshot keeps
 * strings and types, and exposes an empty `items` rather than dead handles.
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
 * The adapter dispatches only for registered elements, and looks one up while
 * `dragstart` bubbles. A capture-phase listener on `window` registers in time
 * for that drag, so adopted content shares the registered sources' dispatch.
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
  const adoption = offeredAdoptions().find((candidate) =>
    // A throw must not stop the candidates after it from being asked.
    consumerMayThrow(() => candidate.match(feedback), false)
  );

  if (!adoption) {
    return;
  }

  liveAdoption?.release();

  let started = false;
  let released = false;

  const cleanup = draggable({
    element: target,
    getInitialData: () => ({
      // Copied inside the guard, so a payload that throws while it is read is
      // caught like one that throws while it is built.
      ...consumerMayThrow(() => ({ ...adoption.getData?.(feedback) }), {}),
      // Last, so consumer data cannot overwrite the routing values and disguise
      // an adopted drag as a registered source, or name a different element as
      // the one being dragged.
      type: ADOPTED_DRAG_TYPE,
      [ADOPTED_AS]: adoption.type,
      [DRAG_BODY]: target,
      native: source,
    }),
    // Fires synchronously during the originating dispatch. The drag-start
    // callback runs later, too late to tell a live drag from one that never was.
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

  // A drag cancelled before it starts fires no event that would release this
  // registration. A run-loop task waits for every listener, a microtask would not.
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

/**
 * Adds a target to the adoption candidates, starting the shared listener.
 *
 * @param getArgsRef - Closure returning the target's latest args.
 * @returns Cleanup; call it once on teardown.
 */
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
