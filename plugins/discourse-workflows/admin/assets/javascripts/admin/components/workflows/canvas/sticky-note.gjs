import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import DCookText from "discourse/ui-kit/d-cook-text";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";
import CanvasHoverToolbar from "./hover-toolbar";
import { DRAG_LENIENCE_PX } from "./rete-editor";

const COLORS = ["yellow", "blue", "green", "pink", "purple", "orange"].map(
  (name) => ({
    name,
    bg: `var(--workflow-sticky-${name})`,
    border: `var(--workflow-sticky-${name}-border)`,
  })
);

const MIN_WIDTH = 140;
const MIN_HEIGHT = 80;
const RESIZE_EDGES = ["n", "s", "w", "e", "nw", "ne", "sw", "se"];

function swatchStyle(colorBg) {
  return trustHTML(`background:${colorBg}`);
}

function stopPropagation(event) {
  event.stopPropagation();
}

const registerStickyNoteElement = modifier((element, [component]) => {
  component.stickyNoteElement = element;

  return () => {
    if (component.stickyNoteElement === element) {
      component.stickyNoteElement = null;
    }
  };
});

export default class StickyNote extends Component {
  @tracked isEditing = false;
  @tracked colorPickerOpen = false;
  stickyNoteElement = null;
  colorOptions = COLORS;
  resizeEdges = RESIZE_EDGES;
  dragLeniencePx = DRAG_LENIENCE_PX;
  handleDocumentClick = (event) => {
    if (!this.stickyNoteElement?.contains(event.target)) {
      this.closeColorPicker();
    }
  };

  #dragOrigin = { x: 0, y: 0 };
  #dragZoom = null;
  #noteDragOpen = false;

  /** How much of the move has already been handed to co-selected notes. */
  #appliedDx = 0;
  #appliedDy = 0;

  /**
   * How many gestures and edits are inside the open mutation. Counted rather
   * than flagged because two handles can be dragged at once, and the first to
   * finish must not close a capture the second is still writing into.
   */
  #openGestures = 0;

  /**
   * Whether editing holds one of those. Kept apart from `isEditing` because
   * reading a tracked field before writing it in the same computation is a
   * backtracking error, and blur can arrive mid-render.
   */
  #editingOpen = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this.closeColorPicker();
    // The note drag and an open edit report nothing of their own on teardown.
    // Left open, the next action's undo baseline becomes this one's, so a single
    // undo jumps further back than the user ever went.
    this.#abandonMutation();
  }

  get style() {
    const { position, size, color } = this.args.note;
    const match = COLORS.find((c) => c.name === color) || COLORS[0];
    const x = Number(position.x) || 0;
    const y = Number(position.y) || 0;
    const w = Number(size.width) || 200;
    const h = Number(size.height) || 150;
    return trustHTML(
      `left:${x}px;top:${y}px;width:${w}px;height:${h}px;background:${match.bg};border-color:${match.border};`
    );
  }

  openColorPicker() {
    if (this.colorPickerOpen) {
      return;
    }

    this.colorPickerOpen = true;

    requestAnimationFrame(() => {
      if (this.colorPickerOpen) {
        document.addEventListener("click", this.handleDocumentClick);
      }
    });
  }

  closeColorPicker() {
    if (!this.colorPickerOpen) {
      return;
    }

    this.colorPickerOpen = false;
    document.removeEventListener("click", this.handleDocumentClick);
  }

  /**
   * Converts a pointer delta from screen pixels into canvas units.
   *
   * @param {{x: number, y: number}} delta - The pointer delta in screen pixels.
   * @param {number} [zoom] - The zoom snapshotted when the gesture began. Reading
   *   it live would re-divide the whole accumulated delta by the new factor and
   *   make the note jump, since the delta is measured from the original press.
   * @returns {{dx: number, dy: number}} The same delta in canvas units.
   */
  #inCanvasUnits(delta, zoom) {
    const factor = zoom ?? this.args.zoom ?? 1;
    return { dx: delta.x / factor, dy: delta.y / factor };
  }

  /**
   * Emits the box this gesture's edge implies, working in edge space.
   *
   * Each boundary moves from where it sat at this gesture's own press, and the
   * three it does not own are read live, so two gestures can hold opposite edges
   * of one axis and compose. Deriving a width from a press-time snapshot instead
   * makes whichever reports later overwrite the other.
   *
   * @param {string} edge - The compass edge being dragged.
   * @param {object} dragInfo - The gesture report, carrying the pointer delta
   *   and the box and zoom this gesture snapshotted at its own press.
   */
  #applyEdgeResize(edge, dragInfo) {
    const { origin, zoom } = dragInfo.session;
    const { dx, dy } = this.#inCanvasUnits(dragInfo.delta, zoom);

    const live = { ...this.args.note.position, ...this.args.note.size };
    let left = live.x;
    let right = live.x + live.width;
    let top = live.y;
    let bottom = live.y + live.height;

    if (edge.includes("e")) {
      right = Math.max(left + MIN_WIDTH, origin.x + origin.width + dx);
    }
    if (edge.includes("w")) {
      left = Math.min(right - MIN_WIDTH, origin.x + dx);
    }
    if (edge.includes("s")) {
      bottom = Math.max(top + MIN_HEIGHT, origin.y + origin.height + dy);
    }
    if (edge.includes("n")) {
      top = Math.min(bottom - MIN_HEIGHT, origin.y + dy);
    }

    this.args.onResize?.({ width: right - left, height: bottom - top });
    // A trailing edge cannot move the origin, and emitting it unchanged would
    // rebuild the whole note list for nothing.
    if (edge.includes("w") || edge.includes("n")) {
      this.args.onMove?.({ x: left, y: top });
    }
  }

  #applyNoteDrag(info) {
    const { dx, dy } = this.#inCanvasUnits(info.delta, this.#dragZoom);

    this.args.onMove?.({
      x: this.#dragOrigin.x + dx,
      y: this.#dragOrigin.y + dy,
    });

    // Any co-selected notes move by the increment since the last report, not by
    // the total, because they are translated relative to wherever they now sit.
    const incrementalDx = dx - this.#appliedDx;
    const incrementalDy = dy - this.#appliedDy;
    if (incrementalDx !== 0 || incrementalDy !== 0) {
      this.args.onTranslateSelected?.(incrementalDx, incrementalDy);
    }
    this.#appliedDx = dx;
    this.#appliedDy = dy;
  }

  #openMutation() {
    this.#openGestures += 1;
    if (this.#openGestures === 1) {
      this.args.onBeforeMutation?.();
    }
  }

  #closeMutation() {
    if (this.#openGestures === 0) {
      return;
    }
    this.#openGestures -= 1;
    if (this.#openGestures === 0) {
      this.args.onAfterMutation?.();
    }
  }

  #closeNoteDrag() {
    if (this.#noteDragOpen) {
      this.#closeMutation();
    }
    this.#noteDragOpen = false;
    this.#dragZoom = null;
  }

  #closeEdgeResize(dragInfo) {
    if (dragInfo.session.opened) {
      dragInfo.session.opened = false;
      this.#closeMutation();
    }
  }

  #abandonMutation() {
    if (this.#openGestures === 0) {
      return;
    }
    this.#openGestures = 0;
    this.args.onAfterMutation?.();
  }

  @action
  onNoteDragStart(event) {
    // The handles carry `stopPropagation`, but one already holding a gesture
    // refuses a second contact *before* stopping it, so that press arrives here.
    if (
      event.target.closest(".workflow-canvas-toolbar") ||
      event.target.closest(".workflow-sticky-note__edge")
    ) {
      return false;
    }

    this.args.onSelect?.();
    // The mutation waits for the first real move: a press that only selects would
    // otherwise bracket an undo entry whose before and after are identical.
    this.#dragZoom = this.args.zoom ?? 1;
    this.#dragOrigin = { ...this.args.note.position };
    this.#appliedDx = 0;
    this.#appliedDy = 0;
    this.#noteDragOpen = false;
  }

  @action
  onNoteDrag(event, info) {
    if (!this.#noteDragOpen) {
      this.#noteDragOpen = true;
      this.#openMutation();
    }
    this.#applyNoteDrag(info);
  }

  @action
  onNoteDragEnd(event, info) {
    if (info.moved) {
      this.#applyNoteDrag(info);
    }
    this.#closeNoteDrag();
  }

  @action
  onNoteDragCancel() {
    // Deliberately no geometry, unlike the release handler: a cancel carries no
    // position the user chose, and the last move already applied where the note
    // was dragged to.
    this.#closeNoteDrag();
  }

  @action
  onEdgeResizeStart(edge, dragInfo) {
    dragInfo.session.origin = {
      ...this.args.note.position,
      ...this.args.note.size,
    };
    dragInfo.session.zoom = this.args.zoom ?? 1;
  }

  @action
  onEdgeResize(edge, dragInfo) {
    if (!dragInfo.session.opened) {
      dragInfo.session.opened = true;
      this.#openMutation();
    }
    this.#applyEdgeResize(edge, dragInfo);
  }

  @action
  onEdgeResizeEnd(edge, dragInfo) {
    // The release can carry a newer position than the last move the browser
    // delivered, so the box is recomputed rather than assumed to match.
    if (dragInfo.moved) {
      this.#applyEdgeResize(edge, dragInfo);
    }
    this.#closeEdgeResize(dragInfo);
  }

  @action
  onEdgeResizeCancel(edge, dragInfo) {
    // No geometry, for the reason given on `onNoteDragCancel`.
    this.#closeEdgeResize(dragInfo);
  }

  @action
  startEditing(event) {
    event.stopPropagation();
    if (this.#editingOpen) {
      return;
    }
    // Through the same counter the gestures use: a press does not move focus off
    // the textarea, so a resize begun mid-edit must nest inside it rather than
    // close it. Entered before the hook, so a hook that throws still leaves the
    // note editable and able to release what it opened.
    this.#editingOpen = true;
    this.isEditing = true;
    this.#openMutation();
  }

  @action
  handleTextInput(event) {
    this.args.onUpdateText?.(event.target.value);
  }

  @action
  stopEditing() {
    if (!this.#editingOpen) {
      return;
    }
    this.#editingOpen = false;
    this.isEditing = false;
    this.#closeMutation();
  }

  @action
  toggleColorPicker(event) {
    event.preventDefault();

    if (this.colorPickerOpen) {
      this.closeColorPicker();
    } else {
      this.openColorPicker();
    }
  }

  @action
  selectColor(colorName, event) {
    event?.preventDefault();
    event?.stopPropagation();
    this.args.onChangeColor?.(colorName);
    this.closeColorPicker();
    this.args.onAfterMutation?.();
  }

  @action
  handleDelete(event) {
    event.stopPropagation();
    this.args.onDelete?.();
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding, ember/template-no-invalid-interactive }}
    <div
      class={{dConcatClass
        "workflow-sticky-note"
        (if @isSelected "is-selected")
        (if this.isEditing "is-editing")
      }}
      style={{this.style}}
      {{registerStickyNoteElement this}}
      {{dPointerDrag
        onDragStart=this.onNoteDragStart
        onDrag=this.onNoteDrag
        onDragEnd=this.onNoteDragEnd
        onDragCancel=this.onNoteDragCancel
        threshold=this.dragLeniencePx
        stopPropagation=true
        touchAction="pinch-zoom"
      }}
      {{on "dblclick" this.startEditing}}
    >
      <CanvasHoverToolbar>
        <DTooltip
          @identifier="sticky-note-change-color"
          @content={{i18n "discourse_workflows.sticky_note.change_color"}}
        >
          <:trigger>
            <button
              type="button"
              class="workflow-canvas-toolbar__btn"
              aria-expanded={{if this.colorPickerOpen "true" "false"}}
              {{on "pointerdown" stopPropagation}}
              {{on "click" this.toggleColorPicker}}
            >
              {{dIcon "palette"}}
            </button>
          </:trigger>
        </DTooltip>
        <DTooltip
          @identifier="sticky-note-delete"
          @content={{i18n "discourse_workflows.sticky_note.delete"}}
        >
          <:trigger>
            <button
              type="button"
              class="workflow-canvas-toolbar__btn"
              {{on "pointerdown" stopPropagation}}
              {{on "click" this.handleDelete}}
            >
              {{dIcon "trash-can"}}
            </button>
          </:trigger>
        </DTooltip>
      </CanvasHoverToolbar>

      {{#if this.colorPickerOpen}}
        <div
          class="workflow-sticky-note__color-picker"
          {{on "pointerdown" stopPropagation}}
        >
          {{#each this.colorOptions as |colorOpt|}}
            <button
              type="button"
              class={{dConcatClass
                "workflow-sticky-note__color-swatch"
                (if (eq @note.color colorOpt.name) "is-active")
              }}
              style={{swatchStyle colorOpt.bg}}
              title={{colorOpt.name}}
              {{on "click" (fn this.selectColor colorOpt.name)}}
            />
          {{/each}}
        </div>
      {{/if}}

      <div class="workflow-sticky-note__content">
        {{#if this.isEditing}}
          <textarea
            class="workflow-sticky-note__textarea"
            value={{@note.text}}
            placeholder={{i18n "discourse_workflows.sticky_note.placeholder"}}
            {{dAutoFocus}}
            {{on "input" this.handleTextInput}}
            {{on "blur" this.stopEditing}}
            {{on "keydown" stopPropagation}}
            {{on "pointerdown" stopPropagation}}
          />
        {{else}}
          <div class="workflow-sticky-note__text">
            {{#if @note.text}}
              <DCookText @rawText={{@note.text}} />
            {{else}}
              <span class="workflow-sticky-note__placeholder">
                {{i18n "discourse_workflows.sticky_note.placeholder"}}
              </span>
            {{/if}}
          </div>
        {{/if}}
      </div>

      <div class="workflow-sticky-note__edges">
        <DResizeHandles
          @handleClass="workflow-sticky-note__edge"
          @directions={{this.resizeEdges}}
          @threshold={{this.dragLeniencePx}}
          @stopPropagation={{true}}
          @onResizeStart={{this.onEdgeResizeStart}}
          @onResize={{this.onEdgeResize}}
          @onResizeEnd={{this.onEdgeResizeEnd}}
          @onResizeCancel={{this.onEdgeResizeCancel}}
        />
      </div>
    </div>
  </template>
}
