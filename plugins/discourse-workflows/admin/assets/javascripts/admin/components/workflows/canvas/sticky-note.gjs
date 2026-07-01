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
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";
import CanvasHoverToolbar from "./hover-toolbar";

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

  handleDocumentClick = (event) => {
    if (!this.stickyNoteElement?.contains(event.target)) {
      this.closeColorPicker();
    }
  };

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

  #startDrag(event, { onMove, onEnd }) {
    event.stopPropagation();
    event.preventDefault();
    const zoom = this.args.zoom ?? 1;
    const startX = event.clientX;
    const startY = event.clientY;

    const moveHandler = (e) => {
      const dx = (e.clientX - startX) / zoom;
      const dy = (e.clientY - startY) / zoom;
      onMove(dx, dy);
    };

    const upHandler = () => {
      document.removeEventListener("pointermove", moveHandler);
      document.removeEventListener("pointerup", upHandler);
      onEnd?.();
    };

    document.addEventListener("pointermove", moveHandler);
    document.addEventListener("pointerup", upHandler);
  }

  @action
  handlePointerDown(event) {
    if (
      event.target.closest(".workflow-sticky-note__edge") ||
      event.target.closest(".workflow-canvas-toolbar") ||
      event.target.tagName === "TEXTAREA"
    ) {
      return;
    }

    this.args.onSelect?.();
    this.args.onBeforeMutation?.();

    const { x, y } = this.args.note.position;
    let prevDx = 0;
    let prevDy = 0;
    this.#startDrag(event, {
      onMove: (dx, dy) => {
        this.args.onMove?.({ x: x + dx, y: y + dy });
        const incrementalDx = dx - prevDx;
        const incrementalDy = dy - prevDy;
        if (incrementalDx !== 0 || incrementalDy !== 0) {
          this.args.onTranslateSelected?.(incrementalDx, incrementalDy);
        }
        prevDx = dx;
        prevDy = dy;
      },
      onEnd: () => this.args.onAfterMutation?.(),
    });
  }

  @action
  handleResizePointerDown(event) {
    const edge = event.target.dataset.edge;
    if (!edge) {
      return;
    }

    this.args.onBeforeMutation?.();

    const { width, height } = this.args.note.size;
    const { x, y } = this.args.note.position;
    const resizeN = edge.includes("n");
    const resizeS = edge.includes("s");
    const resizeW = edge.includes("w");
    const resizeE = edge.includes("e");

    this.#startDrag(event, {
      onMove: (dx, dy) => {
        let newW = width;
        let newH = height;
        let newX = x;
        let newY = y;

        if (resizeE) {
          newW = Math.max(MIN_WIDTH, width + dx);
        }
        if (resizeS) {
          newH = Math.max(MIN_HEIGHT, height + dy);
        }
        if (resizeW) {
          newW = Math.max(MIN_WIDTH, width - dx);
          newX = x + width - newW;
        }
        if (resizeN) {
          newH = Math.max(MIN_HEIGHT, height - dy);
          newY = y + height - newH;
        }

        this.args.onResize?.({ width: newW, height: newH });
        this.args.onMove?.({ x: newX, y: newY });
      },
      onEnd: () => this.args.onAfterMutation?.(),
    });
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
      }}
      style={{this.style}}
      {{registerStickyNoteElement this}}
      {{on "pointerdown" this.handlePointerDown}}
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

      <div
        class="workflow-sticky-note__edges"
        {{on "pointerdown" this.handleResizePointerDown}}
      >
        {{#each this.resizeEdges as |edge|}}
          <div
            class="workflow-sticky-note__edge --{{edge}}"
            data-edge={{edge}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
