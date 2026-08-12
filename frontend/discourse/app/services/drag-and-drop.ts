import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
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
  /** Discriminator string set by the source, or by the adoption that took it. */
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
 * The `type` every adopted drag carries, so a target can tell one apart from a
 * drag a `dDragAndDropSource` registered.
 *
 * Namespaced because it occupies the same slot as a consumer's own `type`: a
 * plugin stamping this literal on a real source would be misrouted into the
 * adoption branch. It cannot be a symbol — `type` is a string everywhere it is
 * read.
 */
export const ADOPTED_DRAG_TYPE = "discourse:adopted-native-drag";

/** Where an adoption's declared type travels, since `type` is the sentinel. */
export const ADOPTED_AS = "adoptedAs";

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
 * For an adopted drag that is the adoption's own declared type rather than the
 * sentinel in `type`, so a consumer filters on the vocabulary it wrote
 * (`"web-link"`) and never has to know a drag was adopted. Without this every
 * filter would miss an adopted drag, leaving an omitted filter — which matches
 * everything — as the only way to catch one.
 *
 * @param data - A drag payload's `data`, as PDND carries it.
 */
export function dragTypeOf(data?: Record<string, unknown>) {
  if (data?.type === ADOPTED_DRAG_TYPE) {
    return data[ADOPTED_AS] as string | undefined;
  }
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
   * is absent.
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
 * Vocabulary `acceptsExternal()` understands. Each key delegates to
 * the matching PDND predicate so the service surface and the modifier
 * surface (`d-drag-and-drop-external-target`) share one vocabulary.
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
 * Tracks the in-flight drag — both for the `dDragAndDropSource` /
 * `dDragAndDropTarget` element pair AND for OS-level external drags
 * (files, URLs, HTML, text entering the window from outside) wired
 * via `dDragAndDropExternalTarget`.
 *
 * Both element and external drag state are populated first-hand by
 * singleton PDND monitors the service registers on construction
 * (`monitorForElements` / `monitorForExternal`) — per-element modifiers
 * don't each carry their own monitor; these are the observers.
 *
 * Lives as a service rather than a module slot so test setup
 * (`setupTest` / `setupRenderingTest`) gets a fresh instance per test,
 * and so modifier classes can inject it via `@service`.
 *
 * Use this to READ drag state for rendering. Use `dDragAndDropMonitor` to RESPOND
 * to a drag imperatively — rendering from its callbacks means hand-maintaining
 * state this service already keeps.
 *
 * Guide to choosing between the gesture primitives:
 * `docs/developer-guides/docs/03-code-internals/29-drag-and-gesture-primitives.md`
 */
export default class DragAndDropService extends Service {
  @tracked currentDrag: DragPayload | null = null;

  @tracked currentExternalDrag: ExternalDragPayload | null = null;

  constructor(...args: ConstructorParameters<typeof Service>) {
    super(...args);
    // Registering a monitor subscribes to the library's drag streams. It does
    // NOT mount the element adapter: only registering a draggable does that, so
    // a page with targets and monitors but no draggable has no element drag
    // listener bound at all.
    //
    // The element monitor is the sole observer of in-flight element drags — the
    // source modifier does not push state here, the service derives it
    // first-hand, mirroring the external monitor below. Only drags carrying a
    // `type` are tracked, so a foreign draggable with none of its own stays
    // invisible here.
    const cleanupElements = monitorForElements({
      canMonitor: ({ source }) =>
        !this.isDestroying && !this.isDestroyed && source.data?.type != null,
      onDragStart: ({ source }) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        // Lifted out rather than passed along: the body is how a drag is
        // routed, not payload a reader of `currentDrag.data` should meet.
        const { [DRAG_BODY]: body, ...data } = source.data ?? {};
        this.setCurrentDrag({
          // `source.data` is PDND's `Record<string, unknown>`; our own
          // `dDragAndDropSource` always stamps `type` as a string, and
          // `canMonitor` above only admits sources whose `type` is set.
          type: dragTypeOf(data) as string,
          data,
          // The body a handled source stands for, so a reader sees the element
          // being moved rather than the grip it was pressed by.
          element: (body as HTMLElement) ?? source.element,
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

  /**
   * `true` if any drag is in flight — element OR external. Lets
   * consumers paint cross-cutting affordances (drop hints, sidebar
   * highlights) without caring which kind of drag started.
   */
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
   * Does the in-flight drag's `type` match the supplied `accepts`
   * filter? Drop targets call this from their event handlers before
   * reacting.
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
   * Does the in-flight EXTERNAL drag carry one of the supplied kinds?
   * Vocabulary mirrors the `accepts` arg on
   * `dDragAndDropExternalTarget`: `"files"`, `"html"`, `"text"`,
   * `"urls"`, or an array of those. A nullish filter matches nothing.
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
   * Re-runs a PDND `contains*` predicate against the live external
   * drag. Done lazily here (rather than caching on `currentExternalDrag`)
   * because the predicate input is the original PDND source — we keep
   * a reconstructed `{source}` shape for it.
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
 * Test-only: end any drag PDND still considers in flight.
 *
 * If a test starts a drag (`dragstart`) but the matching `dragend`/`drop`
 * never reaches PDND — e.g. the source element is torn down first, or an
 * assertion throws mid-drag — PDND's global drag state stays active and the
 * NEXT test's `dragstart` is silently ignored (no second drag can start while
 * one is live). Dispatching a `dragend` lets PDND's lifecycle listener tear the
 * drag down. A no-op when nothing is in flight (the listener is only bound
 * during a drag). Call from the global test teardown.
 */
export function resetDragAndDropForTesting() {
  // PDND binds its drag-phase listeners on `window` (capture) only while a drag
  // is active, and both dispatches are no-ops when nothing is in flight.
  //
  // The order is load-bearing. `dragend` clears the target stack before
  // dispatching its cancellation, so no target `onDrop` runs; a bare `drop`
  // takes PDND's cancel path only when no drop target is under the cursor, and
  // with one it dispatches a real drop, running target callbacks during
  // teardown. Sending `dragend` first leaves the following `drop` a no-op for
  // PDND, whose listeners are unbound by then.
  //
  // This does not silence everything: PDND still dispatches its own `onDrop` to
  // the source and to monitors. A source wrapper deferring its consumer
  // callbacks is what would then schedule them during teardown, and guarding
  // that is its job rather than this function's — `registerDragAndDropSource`
  // cancels the pending task from its own cleanup.
  const make = (type: string) =>
    typeof DragEvent === "function"
      ? new DragEvent(type, { bubbles: true })
      : new Event(type, { bubbles: true });
  for (const type of ["dragend", "drop"]) {
    window.dispatchEvent(make(type));
  }
}
