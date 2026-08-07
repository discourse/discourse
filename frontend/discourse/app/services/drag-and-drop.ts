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
    // Registering a monitor subscribes to PDND's drag streams; the element
    // adapter mounts its window-level listeners through usage registration
    // rather than at module import, so this is what brings it up.
    //
    // The element monitor is the sole observer of in-flight element drags — the
    // source modifier does not push state here, the service derives it
    // first-hand, mirroring the external monitor below. We only track our
    // own drags (those whose `source.data.type` is set by `dDragAndDropSource`),
    // so a foreign PDND draggable doesn't populate `currentDrag`.
    const cleanupElements = monitorForElements({
      canMonitor: ({ source }) =>
        !this.isDestroying && !this.isDestroyed && source.data?.type != null,
      onDragStart: ({ source }) => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        this.setCurrentDrag({
          // `source.data` is PDND's `Record<string, unknown>`; our own
          // `dDragAndDropSource` always stamps `type` as a string, and
          // `canMonitor` above only admits sources whose `type` is set.
          type: source.data.type as string,
          data: source.data,
          element: source.element,
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
        this.currentExternalDrag = this.#decorateExternalSource(source);
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
   * Wraps PDND's raw external source (`{types, items, getStringData}`)
   * with the `contains*` / `get*` helpers bound to that source so
   * consumers can call `service.currentExternalDrag.getFiles()`
   * directly instead of importing PDND helpers. Library wall stays
   * intact — PDND imports live here, not in consumer code.
   */
  #decorateExternalSource(
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
