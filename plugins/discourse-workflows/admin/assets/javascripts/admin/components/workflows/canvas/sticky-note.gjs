import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import CookText from "discourse/components/cook-text";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
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

function focusElement(element) {
  element.focus();
}

function stopPropagation(event) {
  event.stopPropagation();
}

export default class StickyNote extends Component {
  @tracked isEditing = false;
  colorOptions = COLORS;
  resizeEdges = RESIZE_EDGES;

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
  selectColor(colorName, close) {
    this.args.onChangeColor?.(colorName);
    close();
    this.args.onAfterMutation?.();
  }

  @action
  handleDelete(event) {
    event.stopPropagation();
    this.args.onDelete?.();
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding no-invalid-interactive }}
    <div
      class={{concatClass
        "workflow-sticky-note"
        (if @isSelected "is-selected")
      }}
      style={{this.style}}
      {{on "pointerdown" this.handlePointerDown}}
      {{on "dblclick" this.startEditing}}
    >
      <CanvasHoverToolbar>
        <DMenu
          @identifier="sticky-note-color-picker"
          @inline={{true}}
          class="workflow-canvas-toolbar__btn"
          title={{i18n "discourse_workflows.sticky_note.change_color"}}
        >
          <:trigger>
            {{icon "palette"}}
          </:trigger>
          <:content as |args|>
            <div class="workflow-sticky-note__color-picker">
              {{#each this.colorOptions as |colorOpt|}}
                <button
                  type="button"
                  class={{concatClass
                    "workflow-sticky-note__color-swatch"
                    (if (eq @note.color colorOpt.name) "is-active")
                  }}
                  style={{swatchStyle colorOpt.bg}}
                  title={{colorOpt.name}}
                  {{on "click" (fn this.selectColor colorOpt.name args.close)}}
                />
              {{/each}}
            </div>
          </:content>
        </DMenu>
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

      {{! template-lint-disable no-invalid-interactive }}
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
