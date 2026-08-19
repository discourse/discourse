import { tracked } from "@glimmer/tracking";
import { isDestroying, registerDestructor } from "@ember/destroyable";
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
} from "discourse/lib/-internals/drag-and-drop/vocabulary";
import { makeArray } from "discourse/lib/helpers";

/** The in-flight element drag, as the source described it. */
export interface DragPayload {
  /** Discriminator string set by the source. */
  type: string;

  /** Arbitrary payload the source attached to the drag. */
  data: Record<string, unknown>;

  /**
   * The element that originated the drag. `null` only when a caller of
   * `setCurrentDrag` supplied none; the service's own monitor always does.
   */
  element: HTMLElement | null;
}

/**
 * Tracks the in-flight element drag and the in-flight external drag, as the
 * `dDragAndDrop*` modifiers see them, so surfaces can render from drag state.
 *
 * @see The `dDragAndDropMonitor` modifier to respond to a drag imperatively.
 */
export default class DragAndDropService extends Service {
  @tracked currentDrag: DragPayload | null = null;

  @tracked currentExternalDrag: ExternalDragPayload | null = null;

  constructor(...args: ConstructorParameters<typeof Service>) {
    super(...args);
    // A monitor only subscribes to the drag stream; the element listener is
    // bound when a draggable registers, so this costs nothing without one.
    const cleanupElements = monitorForElements({
      canMonitor: ({ source }) =>
        !isDestroying(this) && dragTypeOf(source.data) != null,
      onDragStart: ({ source }) => {
        if (isDestroying(this)) {
          return;
        }
        const normalized = normalizeDragSource(source);
        this.setCurrentDrag({
          // `canMonitor` above only admits sources whose `type` is set, so the
          // `null` a typeless drag would normalize to cannot reach here.
          type: normalized.type as string,
          data: normalized.data,
          element: normalized.element,
        });
      },
      onDrop: () => {
        if (isDestroying(this)) {
          return;
        }
        this.clearCurrentDrag();
      },
    });
    const cleanupExternal = monitorForExternal({
      canMonitor: () => !isDestroying(this),
      onDragStart: ({ source }) => {
        if (isDestroying(this)) {
          return;
        }
        this.currentExternalDrag = decorateExternalSource(source);
      },
      onDrop: () => {
        if (isDestroying(this)) {
          return;
        }
        this.currentExternalDrag = null;
      },
    });
    // This runs deferred, so a monitor callback can still fire after
    // destruction begins. The `isDestroying` guards above cover that gap.
    registerDestructor(this, () => {
      cleanupElements();
      cleanupExternal();
    });
  }

  /** Whether an element or external drag is in flight. */
  get isDragging() {
    return !!(this.currentDrag || this.currentExternalDrag);
  }

  /** Stores the in-flight drag's payload. */
  setCurrentDrag(payload: DragPayload) {
    this.currentDrag = payload;
  }

  /** Clears the in-flight drag. */
  clearCurrentDrag() {
    this.currentDrag = null;
  }

  /**
   * Whether the in-flight drag's `type` is in `accepts`. Unlike a target's
   * `accepts`, a nullish or empty filter matches nothing: a caller that has not
   * decided should not light up for every drag.
   *
   * @param accepts - One type or several. Nullish or empty matches nothing.
   */
  accepts(accepts?: string | string[] | null) {
    if (!this.currentDrag) {
      return false;
    }
    return makeArray(accepts).includes(this.currentDrag.type);
  }

  /**
   * Whether the in-flight external drag carries one of `kinds`. As with
   * {@link accepts}, a nullish or empty filter matches nothing.
   *
   * @param kinds - One kind or several. Nullish or empty matches nothing.
   */
  acceptsExternal(kinds?: ExternalDragKind | ExternalDragKind[] | null) {
    const list = makeArray(kinds);
    if (!this.currentExternalDrag || list.length === 0) {
      return false;
    }
    return matchesExternalKind(list, this.currentExternalDrag);
  }
}
