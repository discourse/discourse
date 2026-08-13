import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import {
  type ElementDragPayload,
  monitorForElements,
} from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import {
  type ExternalDragPayload as NativeExternalDragPayload,
  monitorForExternal,
  type NativeMediaType,
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

/** The in-flight element drag, as the source described it. */
export interface DragPayload {
  /** Discriminator string set by the source. */
  type: string;

  /** Arbitrary payload the source attached to the drag. */
  data: Record<string, unknown>;

  /**
   * The element that originated the drag. The service's own monitor always
   * supplies one; `setCurrentDrag` is public and validates nothing, so a caller
   * driving the service by hand may not.
   */
  element: HTMLElement | null;
}

/**
 * Where the dragged body travels when a source registered a drag handle.
 *
 * The handle is what the underlying library registers, so that the row keeps
 * neither `draggable="true"` nor the unselectable text that attribute brings.
 * The body is the row the handle stands for, and it is what a target reports as
 * `source.element` and compares for `acceptsSelf`.
 *
 * Lives here with the rest of the shared vocabulary because both the source and
 * the target need it, and importing one modifier from the other would close a
 * cycle.
 */
export const DRAG_BODY = "discourse:dragBody";

/**
 * The type a drag answers to in an `accepts` / `types` filter.
 *
 * @param data - A drag payload's `data`, as the underlying library carries it.
 */
export function dragTypeOf(data?: Record<string, unknown>) {
  return data?.type as string | undefined;
}

/**
 * The in-flight external drag, with the read helpers bound to it so consumers
 * never reach for the underlying library themselves.
 */
export interface ExternalDragPayload {
  /**
   * Native MIME types declared by the incoming drag (e.g. `"Files"`,
   * `"text/plain"`, `"text/uri-list"`).
   */
  types: NativeMediaType[];

  /**
   * The `DataTransferItem` list snapshotted at drag start. Browsers expose `kind`
   * and `type` here even when `dataTransfer.getData(…)` is blocked during
   * `dragover` for security.
   */
  items: DataTransferItem[];

  /**
   * Reads the string payload for a given MIME type. Returns `null` when the type
   * is absent or the browser withholds string data during the current drag
   * phase; completed drop callbacks normally receive the readable payload.
   */
  getStringData: (mediaType: string) => string | null;

  containsFiles: () => boolean;
  getFiles: () => File[];
  containsHTML: () => boolean;
  getHTML: () => string | null;
  containsText: () => boolean;
  getText: () => string | null;
  containsURLs: () => boolean;
  getURLs: () => string[];
}

/**
 * Vocabulary `acceptsExternal()` understands. Each key delegates to the
 * matching native-payload predicate so the service and external-target surfaces
 * share one vocabulary.
 */
const EXTERNAL_KIND_PREDICATES = Object.freeze({
  files: containsFiles,
  html: containsHTML,
  text: containsText,
  urls: containsURLs,
});

/** A kind of external payload, as named by `accepts` / `acceptsExternal()`. */
export type ExternalDragKind = keyof typeof EXTERNAL_KIND_PREDICATES;

/**
 * Wraps the underlying library's raw external payload
 * (`{types, items, getStringData}`) with the `contains*` / `get*` helpers bound
 * to it, so a consumer calls `source.getFiles()` rather than importing the
 * library's helpers itself.
 *
 * Lives here rather than beside either drop target because both targets and this
 * service need it, and the external target already imports from the element one
 * — a copy in either would close an import cycle the moment a third reader
 * appeared.
 *
 * @param source - The raw payload the library reports.
 */
export function decorateExternalSource(
  source: NativeExternalDragPayload
): ExternalDragPayload {
  return {
    types: source.types,
    items: source.items,
    getStringData: (mediaType) => source.getStringData(mediaType),
    containsFiles: () => containsFiles({ source }),
    getFiles: () => getFiles({ source }),
    containsHTML: () => containsHTML({ source }),
    getHTML: () => getHTML({ source }),
    containsText: () => containsText({ source }),
    getText: () => getText({ source }),
    containsURLs: () => containsURLs({ source }),
    getURLs: () => getURLs({ source }),
  };
}

/**
 * Whether an incoming external drag is one of the named kinds.
 *
 * An empty or missing filter matches every external drag, mirroring how the
 * element target treats an absent `accepts`. Shared so everything filtering on
 * this vocabulary agrees on what a kind name means; the element-side
 * counterpart is `matchesDragType`.
 *
 * @param accepts - The kind filter as the consumer supplied it.
 * @param source - The raw payload the underlying library reports.
 */
export function matchesExternalKind(
  accepts: ExternalDragKind | ExternalDragKind[] | undefined,
  source: NativeExternalDragPayload
) {
  const kinds = accepts ? (Array.isArray(accepts) ? accepts : [accepts]) : [];
  if (kinds.length === 0) {
    return true;
  }
  return kinds.some((kind) => {
    const predicate = EXTERNAL_KIND_PREDICATES[kind];
    // Unknown kind names fail closed — better than silently matching.
    return predicate ? predicate({ source }) : false;
  });
}

/**
 * A drag source as consumers read it: routing keys lifted out and the dragged
 * body in place of the grip that carried it.
 */
export interface NormalizedDragSource {
  /** The source's discriminator, or `null` when the drag carries none. */
  type: string | null;

  /** The payload the source attached to the drag. */
  data: Record<string, unknown>;

  /** The dragged element, or `null` when the drag has none. */
  element: Element | null;
}

/**
 * Resolves a raw payload into the shape every reader reports.
 *
 * This is the single place the routing vocabulary above is interpreted. The
 * drop target, the monitor modifier, and this service all consume it, so a
 * payload reads identically wherever a consumer meets it — a shape one of them
 * derived by hand drifted once already.
 *
 * @param source - The payload as the underlying library carries it.
 * @param fallbackElement - Reported as `element` when the drag itself has none;
 *   a drop target passes itself here.
 */
export function normalizeDragSource(
  source: ElementDragPayload,
  fallbackElement?: Element
): NormalizedDragSource {
  // Lifted out first: the body is routing, not payload, so no consumer should
  // ever iterate onto it.
  const { [DRAG_BODY]: body, ...data } = source.data ?? {};

  return {
    // The underlying library types every payload value as `unknown`, because
    // anything registering a draggable with it can put anything there.
    // `dDragAndDropSource` always stamps its discriminator as a string.
    type: (data.type ?? null) as string | null,
    data,
    // A source that registered a handle publishes the body it stands for, so a
    // consumer receives the element the user is moving rather than the grip
    // they happened to press.
    element: (body as Element) ?? source.element ?? fallbackElement ?? null,
  };
}

/**
 * Tracks in-flight drags from both the `dDragAndDropSource` /
 * `dDragAndDropTarget` element pair and the OS-level payloads wired through
 * `dDragAndDropExternalTarget`.
 *
 * Both states are populated first-hand by singleton monitors this service
 * registers on construction. Per-element modifiers do not each carry their own
 * monitor; these are the observers.
 *
 * Lives as a service rather than a module slot so test setup
 * (`setupTest` / `setupRenderingTest`) gets a fresh instance per test.
 *
 * Use this to READ drag state for rendering. Use `dDragAndDropMonitor` to
 * RESPOND to a drag imperatively — rendering from its callbacks means
 * hand-maintaining state this service already keeps.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 */
export default class DragAndDropService extends Service {
  @tracked currentDrag: DragPayload | null = null;

  @tracked currentExternalDrag: ExternalDragPayload | null = null;

  constructor(...args: ConstructorParameters<typeof Service>) {
    super(...args);
    // Registering a monitor subscribes to the library's drag stream. It does
    // NOT mount the element adapter: only registering a draggable does that, so
    // a page with targets and monitors but no draggable has no element drag
    // listener bound at all.
    //
    // The monitor is the sole observer of in-flight element drags — the source
    // modifier does not push state here, the service derives it first-hand.
    // Only drags carrying a `type` are tracked, so a foreign draggable with
    // none of its own stays invisible here.
    const cleanupElements = monitorForElements({
      canMonitor: ({ source }) =>
        !this.isDestroying &&
        !this.isDestroyed &&
        dragTypeOf(source.data) != null,
      onDragStart: ({ source }) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        const normalized = normalizeDragSource(source);
        this.setCurrentDrag({
          // `canMonitor` above only admits sources whose `type` is set, so the
          // `null` a typeless drag would normalize to cannot reach here.
          type: normalized.type as string,
          data: normalized.data,
          element: normalized.element as HTMLElement,
        });
      },
      onDrop: () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.clearCurrentDrag();
      },
    });
    // Guarded the same way as the element monitor above: a drag still in flight
    // when the service is torn down would otherwise write tracked state on a
    // destroyed object.
    const cleanupExternal = monitorForExternal({
      canMonitor: () => !this.isDestroying && !this.isDestroyed,
      onDragStart: ({ source }) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.currentExternalDrag = decorateExternalSource(source);
      },
      onDrop: () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.currentExternalDrag = null;
      },
    });
    registerDestructor(this, () => {
      cleanupElements();
      cleanupExternal();
    });
  }

  /** Whether an element or external drag is in flight. */
  get isDragging() {
    return !!(this.currentDrag || this.currentExternalDrag);
  }

  /**
   * Stores the in-flight drag's payload. Called by the service's own
   * `monitorForElements` on drag start.
   */
  setCurrentDrag(payload: DragPayload) {
    this.currentDrag = payload;
  }

  /**
   * Clears the in-flight drag. Called by the service's own
   * `monitorForElements` on drop — fires regardless of whether the drop
   * landed on a target or was cancelled.
   */
  clearCurrentDrag() {
    this.currentDrag = null;
  }

  /**
   * Does the in-flight drag's `type` match the supplied `accepts` filter?
   *
   * @param accepts - Single type string or array. A nullish filter matches
   *   nothing, so a target can pass its unset arg straight through.
   */
  accepts(accepts?: string | string[] | null) {
    if (!this.currentDrag || !accepts) {
      return false;
    }
    if (Array.isArray(accepts)) {
      return accepts.includes(this.currentDrag.type);
    }
    return this.currentDrag.type === accepts;
  }

  /**
   * Does the in-flight external drag carry one of the supplied kinds?
   *
   * The vocabulary mirrors the `accepts` argument on
   * `dDragAndDropExternalTarget`: `"files"`, `"html"`, `"text"`, `"urls"`, or
   * an array of those. A nullish filter matches nothing.
   */
  acceptsExternal(kinds?: ExternalDragKind | ExternalDragKind[] | null) {
    if (!this.currentExternalDrag || !kinds) {
      return false;
    }
    const list = Array.isArray(kinds) ? kinds : [kinds];
    return list.some((kind) => {
      const predicate = EXTERNAL_KIND_PREDICATES[kind];
      return predicate ? this.#callExternalPredicate(predicate) : false;
    });
  }

  /**
   * Re-runs a native-payload predicate against the live external drag. Done
   * lazily rather than cached so it receives the original source shape.
   */
  #callExternalPredicate(
    predicate: (typeof EXTERNAL_KIND_PREDICATES)[ExternalDragKind]
  ) {
    return predicate({
      source: {
        types: this.currentExternalDrag.types,
        items: this.currentExternalDrag.items,
        getStringData: this.currentExternalDrag.getStringData,
      },
    });
  }
}

/**
 * Test-only: end any drag the underlying library still considers in flight.
 *
 * If a test starts a drag (`dragstart`) but the matching `dragend` / `drop`
 * never reaches the library — e.g. the source element is torn down first, or an
 * assertion throws mid-drag — its global drag state stays active and the next
 * test's `dragstart` is silently ignored. Dispatching a `dragend` lets the
 * lifecycle listener tear the drag down. A no-op when nothing is in flight.
 * Call from the global test teardown.
 */
export function resetDragAndDropForTesting() {
  // The library binds its drag-phase listeners on `window` (capture) only
  // while a drag is active, and both dispatches are no-ops when nothing is in
  // flight.
  //
  // The order is load-bearing. `dragend` clears the target stack before
  // dispatching its cancellation, so no target `onDrop` runs; a bare `drop`
  // takes the cancel path only when no drop target is under the cursor, and with
  // one it dispatches a real drop, running target callbacks during teardown.
  // Sending `dragend` first leaves the following `drop` a no-op, because the
  // listeners are unbound by then.
  //
  // This does not silence everything: the library still dispatches its own
  // `onDrop` to the source and to monitors. A source wrapper deferring its
  // consumer callbacks is what would then schedule them during teardown, and
  // guarding that is its job rather than this function's —
  // `registerDragAndDropSource` cancels the pending task from its own cleanup.
  const make = (type: string) =>
    typeof DragEvent === "function"
      ? new DragEvent(type, { bubbles: true })
      : new Event(type, { bubbles: true });
  for (const type of ["dragend", "drop"]) {
    window.dispatchEvent(make(type));
  }
}
