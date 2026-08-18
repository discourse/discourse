import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service from "@ember/service";
import { monitorForElements } from "@atlaskit/pragmatic-drag-and-drop/adapter/element-adapter";
import { monitorForExternal } from "@atlaskit/pragmatic-drag-and-drop/adapter/monitor-for-external";
import {
  decorateExternalSource,
  type ExternalDragKind,
  type ExternalDragPayload,
  matchesExternalKind,
} from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import {
  dragTypeOf,
  normalizeDragSource,
  toAcceptList,
} from "discourse/lib/-internals/drag-and-drop/vocabulary";

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
        this.#alive && dragTypeOf(source.data) != null,
      onDragStart: ({ source }) => {
        if (!this.#alive) {
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
        if (!this.#alive) {
          return;
        }
        this.clearCurrentDrag();
      },
    });
    // Guarded the same way as the element monitor above: a drag still in flight
    // when the service is torn down would otherwise write tracked state on a
    // destroyed object.
    const cleanupExternal = monitorForExternal({
      canMonitor: () => this.#alive,
      onDragStart: ({ source }) => {
        if (!this.#alive) {
          return;
        }
        this.currentExternalDrag = decorateExternalSource(source);
      },
      onDrop: () => {
        if (!this.#alive) {
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

  get #alive() {
    return !this.isDestroying && !this.isDestroyed;
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
   * The opposite default from the drop target and the monitor, on purpose. There an
   * omitted or empty filter accepts every drag, because a target that filters
   * nothing is a real configuration.
   *
   * Here a nullish or empty filter means the caller has not decided, so it
   * matches nothing.
   *
   * @param accepts - Single type string or array. Nullish or empty matches nothing.
   */
  accepts(accepts?: string | string[] | null) {
    if (!this.currentDrag) {
      return false;
    }
    return toAcceptList(accepts).includes(this.currentDrag.type);
  }

  /**
   * Does the in-flight external drag carry one of the supplied kinds?
   *
   * The vocabulary mirrors the `accepts` argument on
   * `dDragAndDropExternalTarget`: `"files"`, `"html"`, `"text"`, `"urls"`, or
   * an array of those. As with {@link accepts}, a nullish or empty filter
   * matches nothing.
   */
  acceptsExternal(kinds?: ExternalDragKind | ExternalDragKind[] | null) {
    const list = toAcceptList(kinds);
    if (!this.currentExternalDrag || list.length === 0) {
      return false;
    }
    return matchesExternalKind(list, this.currentExternalDrag);
  }
}
