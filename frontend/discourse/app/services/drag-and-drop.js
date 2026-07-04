// @ts-check
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/element/adapter";
import { monitorForExternal } from "@atlaskit/pragmatic-drag-and-drop/external/adapter";
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

/**
 * @typedef {Object} DragPayload
 * @property {string} type - Discriminator string set by the source.
 * @property {*} data - Arbitrary payload the source attached to the drag.
 * @property {Element} element - The element that originated the drag.
 */

/**
 * @typedef {Object} ExternalDragPayload
 * @property {string[]} types - Native MIME types declared by the
 *   incoming drag (e.g. `"Files"`, `"text/plain"`, `"text/uri-list"`).
 * @property {DataTransferItem[]} items - The `DataTransferItem` list
 *   PDND snapshotted at drag start. Browsers expose `kind` and `type`
 *   here even when `dataTransfer.getData(…)` is blocked during
 *   `dragover` for security.
 * @property {(mediaType: string) => string | null} getStringData -
 *   Reads the string payload for a given MIME type. Returns `null`
 *   when the type is absent.
 * @property {() => boolean} containsFiles
 * @property {() => File[]} getFiles
 * @property {() => boolean} containsHTML
 * @property {() => string | null} getHTML
 * @property {() => boolean} containsText
 * @property {() => string | null} getText
 * @property {() => boolean} containsURLs
 * @property {() => string[]} getURLs
 */

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
 */
export default class DragAndDropService extends Service {
  /** @type {DragPayload|null} */
  @tracked currentDrag = null;

  /** @type {ExternalDragPayload|null} */
  @tracked currentExternalDrag = null;

  constructor() {
    super(...arguments);
    // PDND's adapters bind their window-level listeners on module import;
    // registering monitors here just subscribes to those streams. Eager
    // registration keeps the service's public state populated for any consumer
    // that reads `currentDrag` / `currentExternalDrag` / `accepts(…)` without
    // requiring them to opt in first.
    //
    // The element monitor is the single observer of in-flight element drags —
    // `dDragAndDropSource` no longer pushes the state; the service derives it
    // first-hand here, mirroring the external monitor below. We only track our
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
          type: /** @type {string} */ (source.data.type),
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
    const cleanupExternal = monitorForExternal({
      onDragStart: ({ source }) => {
        this.currentExternalDrag = this.#decorateExternalSource(source);
      },
      onDrop: () => {
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
   *
   * @returns {boolean}
   */
  get isDragging() {
    return !!(this.currentDrag || this.currentExternalDrag);
  }

  /**
   * Stores the in-flight drag's payload. Called by the service's own
   * `monitorForElements` on drag start.
   *
   * @param {DragPayload} payload
   */
  setCurrentDrag(payload) {
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
   * @param {string|string[]} accepts - Single type string or array.
   * @returns {boolean}
   */
  accepts(accepts) {
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
   * `"urls"`, or an array of those.
   *
   * @param {string|string[]} kinds
   * @returns {boolean}
   */
  acceptsExternal(kinds) {
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
   * @deprecated — use `accepts` instead. Kept here only as a guardrail
   *   for legacy callers we may have missed; will be removed once the
   *   migration is complete.
   * @param {string|string[]} accepts
   * @returns {boolean}
   */
  isAccepted(accepts) {
    return this.accepts(accepts);
  }

  /**
   * Wraps PDND's raw external source (`{types, items, getStringData}`)
   * with the `contains*` / `get*` helpers bound to that source so
   * consumers can call `service.currentExternalDrag.getFiles()`
   * directly instead of importing PDND helpers. Library wall stays
   * intact — PDND imports live here, not in consumer code.
   */
  #decorateExternalSource(source) {
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
  #callExternalPredicate(predicate) {
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
  // is active, and ends the drag from either `drop` (with no drop targets) or
  // `dragend`. Dispatching both covers either path; both are no-ops when no
  // drag is in flight (the listeners aren't bound).
  const make = (type) =>
    typeof DragEvent === "function"
      ? new DragEvent(type, { bubbles: true })
      : new Event(type, { bubbles: true });
  for (const type of ["drop", "dragend"]) {
    window.dispatchEvent(make(type));
  }
}
