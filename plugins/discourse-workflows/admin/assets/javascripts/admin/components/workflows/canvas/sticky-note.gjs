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
  /** Where the pointer went down, so a move reports its total travel. */
  #pressX = 0;
  #pressY = 0;
  /** The note's position when the move gesture began. */
  #dragOrigin = { x: 0, y: 0 };
  /** How much of the move has already been handed to co-selected notes. */
  #appliedDx = 0;
  #appliedDy = 0;
  /** The note's box when the resize gesture began. */
  #resizeOrigin = { x: 0, y: 0, width: 0, height: 0 };
  /** The canvas zoom in force when the live gesture began. */
  #gestureZoom = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.closeColorPicker();
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
   * Converts a pointer delta from screen pixels into canvas units. The canvas is
   * scaled, so a 10px pointer move is a smaller move of the note when zoomed in.
   *
   * @param {{x: number, y: number}} delta - The pointer delta in screen pixels.
   * @returns {{dx: number, dy: number}} The same delta in canvas units.
   */
  #inCanvasUnits(delta) {
    // Snapshotted at the start of the gesture: zooming mid-drag would otherwise
    // re-divide the whole accumulated delta by the new factor and make the note
    // jump, because the delta is measured from the original press.
    const zoom = this.#gestureZoom ?? this.args.zoom ?? 1;
    return { dx: delta.x / zoom, dy: delta.y / zoom };
  }

  @action
  onNoteDragStart(event) {
    // The toolbar's own buttons stop the press themselves, but the strip around
    // them does not, and pressing it has never dragged the note.
    if (event.target.closest(".workflow-canvas-toolbar")) {
      return false;
    }

    this.args.onSelect?.();
    this.args.onBeforeMutation?.();
    this.#gestureZoom = this.args.zoom ?? 1;
    this.#pressX = event.clientX;
    this.#pressY = event.clientY;
    this.#dragOrigin = { ...this.args.note.position };
    this.#appliedDx = 0;
    this.#appliedDy = 0;
  }

  @action
  onNoteDrag(event) {
    const { dx, dy } = this.#inCanvasUnits({
      x: event.clientX - this.#pressX,
      y: event.clientY - this.#pressY,
    });

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

  @action
  onNoteDragEnd() {
    this.#gestureZoom = null;
    this.args.onAfterMutation?.();
  }

  @action
  onEdgeResizeStart() {
    this.args.onBeforeMutation?.();
    this.#gestureZoom = this.args.zoom ?? 1;
    this.#resizeOrigin = {
      ...this.args.note.position,
      ...this.args.note.size,
    };
  }

  @action
  onEdgeResize(edge, dragInfo) {
    const { x, y, width, height } = this.#resizeOrigin;
    const { dx, dy } = this.#inCanvasUnits(dragInfo.delta);

    let newWidth = width;
    let newHeight = height;
    let newX = x;
    let newY = y;

    if (edge.includes("e")) {
      newWidth = Math.max(MIN_WIDTH, width + dx);
    }
    if (edge.includes("s")) {
      newHeight = Math.max(MIN_HEIGHT, height + dy);
    }
    // Dragging a leading edge moves the note's origin by however much the box
    // actually grew, which the minimum may have capped.
    if (edge.includes("w")) {
      newWidth = Math.max(MIN_WIDTH, width - dx);
      newX = x + width - newWidth;
    }
    if (edge.includes("n")) {
      newHeight = Math.max(MIN_HEIGHT, height - dy);
      newY = y + height - newHeight;
    }

    this.args.onResize?.({ width: newWidth, height: newHeight });
    this.args.onMove?.({ x: newX, y: newY });
  }

  @action
  onEdgeResizeEnd() {
    this.#gestureZoom = null;
    this.args.onAfterMutation?.();
  }

  @action
  startEditing(event) {
    event.stopPropagation();
    this.args.onBeforeMutation?.();
    this.isEditing = true;
  }

  @action
  handleTextInput(event) {
    this.args.onUpdateText?.(event.target.value);
  }

  @action
  stopEditing() {
    this.isEditing = false;
    this.args.onAfterMutation?.();
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
        onDragCancel=this.onNoteDragEnd
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
          @onResizeCancel={{this.onEdgeResizeEnd}}
        />
      </div>
    </div>
  </template>
}
