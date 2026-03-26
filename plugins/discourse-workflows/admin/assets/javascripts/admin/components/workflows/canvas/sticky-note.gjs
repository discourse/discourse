import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import CookText from "discourse/components/cook-text";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import CanvasHoverToolbar from "./hover-toolbar";

const COLORS = [
  {
    name: "yellow",
    bg: "var(--workflow-sticky-yellow)",
    border: "var(--workflow-sticky-yellow-border)",
  },
  {
    name: "blue",
    bg: "var(--workflow-sticky-blue)",
    border: "var(--workflow-sticky-blue-border)",
  },
  {
    name: "green",
    bg: "var(--workflow-sticky-green)",
    border: "var(--workflow-sticky-green-border)",
  },
  {
    name: "pink",
    bg: "var(--workflow-sticky-pink)",
    border: "var(--workflow-sticky-pink-border)",
  },
  {
    name: "purple",
    bg: "var(--workflow-sticky-purple)",
    border: "var(--workflow-sticky-purple-border)",
  },
  {
    name: "orange",
    bg: "var(--workflow-sticky-orange)",
    border: "var(--workflow-sticky-orange-border)",
  },
];

const MIN_WIDTH = 140;
const MIN_HEIGHT = 80;

function swatchStyle(colorBg) {
  return trustHTML(`background:${colorBg}`);
}

function focusElement(element) {
  element.focus();
}

function stopPropagation(event) {
  event.stopPropagation();
}

export default class StickyNote extends Component {
  @tracked isEditing = false;
  @tracked showColorPicker = false;

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

  get colorOptions() {
    return COLORS;
  }

  #trackPointerDrag(event, { onMove, onEnd }) {
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

    this.showColorPicker = false;
    this.args.onSelect?.();
    this.args.onDragStart?.();

    const { x, y } = this.args.note.position;
    this.#trackPointerDrag(event, {
      onMove: (dx, dy) => this.args.onMove?.({ x: x + dx, y: y + dy }),
      onEnd: () => this.args.onDragEnd?.(),
    });
  }

  @action
  handleResizePointerDown(event) {
    const edge = event.target.dataset.edge;
    if (!edge) {
      return;
    }

    this.args.onDragStart?.();

    const { width, height } = this.args.note.size;
    const { x, y } = this.args.note.position;
    const resizeN = edge.includes("n");
    const resizeS = edge.includes("s");
    const resizeW = edge.includes("w");
    const resizeE = edge.includes("e");

    this.#trackPointerDrag(event, {
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
      onEnd: () => this.args.onDragEnd?.(),
    });
  }

  @action
  startEditing(event) {
    event.stopPropagation();
    this.args.onDragStart?.();
    this.isEditing = true;
  }

  @action
  handleTextInput(event) {
    this.args.onUpdateText?.(event.target.value);
  }

  @action
  stopEditing() {
    this.isEditing = false;
    this.args.onDragEnd?.();
  }

  @action
  toggleColorPicker(event) {
    event.stopPropagation();
    this.showColorPicker = !this.showColorPicker;
  }

  @action
  selectColor(colorName, event) {
    event.stopPropagation();
    this.args.onChangeColor?.(colorName);
    this.showColorPicker = false;
    this.args.onDragEnd?.();
  }

  @action
  handleDelete(event) {
    event.stopPropagation();
    this.args.onDelete?.();
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding no-invalid-interactive }}
    <div
      class="workflow-sticky-note {{if @isSelected '--selected'}}"
      style={{this.style}}
      {{on "pointerdown" this.handlePointerDown}}
      {{on "dblclick" this.startEditing}}
    >
      <CanvasHoverToolbar>
        <button
          type="button"
          class="workflow-canvas-toolbar__btn"
          title={{i18n "discourse_workflows.sticky_note.change_color"}}
          {{on "pointerdown" stopPropagation}}
          {{on "click" this.toggleColorPicker}}
        >
          {{icon "palette"}}
        </button>
        <button
          type="button"
          class="workflow-canvas-toolbar__btn"
          title={{i18n "discourse_workflows.sticky_note.delete"}}
          {{on "pointerdown" stopPropagation}}
          {{on "click" this.handleDelete}}
        >
          {{icon "trash-can"}}
        </button>
      </CanvasHoverToolbar>

      {{#if this.showColorPicker}}
        <div class="workflow-sticky-note__color-picker">
          {{#each this.colorOptions as |colorOpt|}}
            <button
              type="button"
              class="workflow-sticky-note__color-swatch
                {{if (eq @note.color colorOpt.name) '--active'}}"
              style={{swatchStyle colorOpt.bg}}
              title={{colorOpt.name}}
              {{on "pointerdown" stopPropagation}}
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
            {{didInsert focusElement}}
            {{on "input" this.handleTextInput}}
            {{on "blur" this.stopEditing}}
            {{on "keydown" stopPropagation}}
            {{on "pointerdown" stopPropagation}}
          />
        {{else}}
          <div class="workflow-sticky-note__text">
            {{#if @note.text}}
              <CookText @rawText={{@note.text}} />
            {{else}}
              <span class="workflow-sticky-note__placeholder">
                {{i18n "discourse_workflows.sticky_note.placeholder"}}
              </span>
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{! resize edges }}
      <div
        class="workflow-sticky-note__edge --n"
        data-edge="n"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --s"
        data-edge="s"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --w"
        data-edge="w"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --e"
        data-edge="e"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --nw"
        data-edge="nw"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --ne"
        data-edge="ne"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --sw"
        data-edge="sw"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
      <div
        class="workflow-sticky-note__edge --se"
        data-edge="se"
        {{on "pointerdown" this.handleResizePointerDown}}
      />
    </div>
  </template>
}
