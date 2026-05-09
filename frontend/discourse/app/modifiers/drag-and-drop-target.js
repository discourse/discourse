// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";

/**
 * Per-axis CSS class names toggled while the cursor is hovering with a
 * compatible drag in flight. Mirrored in the foundation styles at
 * `app/assets/stylesheets/common/foundation/draggable.scss` so consumers
 * get a 2px tertiary indicator above/below the row by default and can
 * override with their own treatment when a different look is needed.
 */
const POSITION_CLASSES = Object.freeze({
  before: { y: "is-drag-above", x: "is-drag-left" },
  after: { y: "is-drag-below", x: "is-drag-right" },
  inside: { y: "is-drag-inside", x: "is-drag-inside" },
});

/**
 * Marks an element as a drop target compatible with the
 * `drag-and-drop-source` vocabulary. Call from a row, container, or a
 * fixed-position drop zone.
 *
 * Smart row mode — position is computed from the cursor against the
 * element's midpoint:
 *
 * ```hbs
 * <li {{dragAndDropTarget
 *   accepts="sidebar-link"
 *   onDrop=this.reorder
 * }}>...</li>
 * ```
 *
 * Fixed-position mode — for explicit "before" / "after" / "inside" zones
 * (e.g. the visual-editor's drop strips) where the slot is decided by
 * geometry, not by the cursor:
 *
 * ```hbs
 * <div {{dragAndDropTarget
 *   accepts="ve-block"
 *   position="inside"
 *   onDrop=this.applyMove
 * }}></div>
 * ```
 *
 * Nested-target behaviour: when multiple `drag-and-drop-target`-decorated
 * elements are stacked, the deepest accepted match wins. We achieve that
 * with two idioms native to HTML5 DnD:
 *   1. `dragenter`/`dragleave` use a depth counter so spurious leaves
 *      from crossing inner DOM children don't clear the indicator.
 *   2. `dragover`/`drop` call `event.stopPropagation()` once the source's
 *      kind is accepted, so an ancestor target doesn't double-handle.
 * A parent target whose `accepts` matches still receives `onDragEnter` —
 * it just doesn't claim the *drop*. This lets a section highlight while
 * a link inside it is being hovered, for example.
 */
export default class DragAndDropTargetModifier extends Modifier {
  @service dragAndDrop;

  element;
  accepts;
  position;
  axis = "y";
  onDragEnter;
  onDragLeave;
  onDrop;
  canDrop;

  enterDepth = 0;
  activeClasses = new Set();
  leaveTimer = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element,
    _positional,
    {
      accepts,
      position,
      axis = "y",
      onDragEnter,
      onDragLeave,
      onDrop,
      canDrop,
    } = {}
  ) {
    if (this.element && this.element !== element) {
      this.cleanup();
    }
    if (!this.element) {
      element.addEventListener("dragenter", this.handleDragEnter);
      element.addEventListener("dragover", this.handleDragOver);
      element.addEventListener("dragleave", this.handleDragLeave);
      element.addEventListener("drop", this.handleDrop);
    }
    this.element = element;
    this.accepts = accepts;
    this.position = position;
    this.axis = axis;
    this.onDragEnter = onDragEnter;
    this.onDragLeave = onDragLeave;
    this.onDrop = onDrop;
    this.canDrop = canDrop;
  }

  /** Whether the in-flight drag is allowed to drop here. */
  get isAccepted() {
    if (!this.dragAndDrop.isAccepted(this.accepts)) {
      return false;
    }
    if (this.canDrop) {
      return this.canDrop({ source: this.dragAndDrop.currentDrag }) !== false;
    }
    return true;
  }

  /**
   * Computes whether the cursor is in the "before" or "after" half of the
   * element along the configured axis. Returns the fixed `position` arg
   * when one was supplied.
   */
  resolvePosition(event) {
    if (this.position) {
      return this.position;
    }
    const rect = this.element.getBoundingClientRect();
    if (this.axis === "x") {
      return event.clientX < rect.left + rect.width / 2 ? "before" : "after";
    }
    return event.clientY < rect.top + rect.height / 2 ? "before" : "after";
  }

  /**
   * Toggles the per-axis indicator class (e.g. `is-drag-above`) for the
   * resolved position. We track which class is currently active so we can
   * clear it cleanly when the drag leaves or the position flips.
   */
  applyIndicator(position) {
    const className = POSITION_CLASSES[position]?.[this.axis];
    if (!className) {
      return;
    }
    if (this.activeClasses.has(className)) {
      return;
    }
    for (const stale of this.activeClasses) {
      this.element.classList.remove(stale);
    }
    this.activeClasses.clear();
    this.element.classList.add(className);
    this.activeClasses.add(className);
  }

  clearIndicators() {
    for (const className of this.activeClasses) {
      this.element.classList.remove(className);
    }
    this.activeClasses.clear();
  }

  @bind
  handleDragEnter(event) {
    this.enterDepth++;
    if (this.enterDepth !== 1) {
      // Cursor crossed into a child node we already had under us; the
      // boundary was crossed earlier and we already fired onDragEnter.
      return;
    }
    if (!this.isAccepted) {
      return;
    }
    if (this.leaveTimer) {
      // The cursor briefly left and came back before the deferred clear
      // ran. Cancel the pending clear so the indicator doesn't flicker.
      this.leaveTimer = null;
    }
    this.onDragEnter?.({
      source: this.dragAndDrop.currentDrag,
      element: this.element,
      position: this.position ?? null,
      event,
    });
  }

  @bind
  handleDragOver(event) {
    if (!this.isAccepted) {
      return;
    }
    // preventDefault is the HTML5 contract that says "I can accept this
    // drop"; without it the drop event is never dispatched. stopPropagation
    // ensures an ancestor drop-target doesn't also claim this drag — the
    // deepest accepted target wins.
    event.preventDefault();
    event.stopPropagation();
    const position = this.resolvePosition(event);
    this.applyIndicator(position);
  }

  @bind
  handleDragLeave(event) {
    this.enterDepth = Math.max(0, this.enterDepth - 1);
    if (this.enterDepth !== 0) {
      return;
    }
    // 10ms deferred clear: hides flicker when the cursor crosses
    // internal DOM siblings — a transient dragleave fires, immediately
    // followed by a dragenter on the sibling, and we don't want the
    // indicator to blink off in between. Inline ad-hoc DnD code in
    // `app/components/sidebar/section-form-link.gjs` and
    // `plugins/discourse-doc-categories/.../section.gjs` predates this
    // modifier and reimplements the same trick by hand; future PRs can
    // collapse them onto this implementation.
    //
    // Note: by the time `discourseLater` fires, `event.currentTarget` has
    // been cleared by the browser (it's only valid synchronously inside
    // the original event handler). Consumers reading positional metadata
    // should take it from the modifier-supplied `position` / `element`,
    // not from `event.currentTarget` — the latter is null after the
    // deferred microtask.
    const myToken = (this.leaveTimer = {});
    discourseLater(() => {
      if (this.leaveTimer === myToken && this.enterDepth === 0) {
        this.clearIndicators();
        this.leaveTimer = null;
        this.onDragLeave?.({
          source: this.dragAndDrop.currentDrag,
          element: this.element,
          position: this.position ?? null,
          event,
        });
      }
    }, 10);
  }

  @bind
  handleDrop(event) {
    this.enterDepth = 0;
    this.leaveTimer = null;
    if (!this.isAccepted) {
      this.clearIndicators();
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    const position = this.resolvePosition(event);
    const source = this.dragAndDrop.currentDrag;
    this.clearIndicators();
    this.onDrop?.({ source, position, element: this.element, event });
  }

  cleanup() {
    if (!this.element) {
      return;
    }
    this.element.removeEventListener("dragenter", this.handleDragEnter);
    this.element.removeEventListener("dragover", this.handleDragOver);
    this.element.removeEventListener("dragleave", this.handleDragLeave);
    this.element.removeEventListener("drop", this.handleDrop);
    this.clearIndicators();
    this.enterDepth = 0;
    this.leaveTimer = null;
  }
}
