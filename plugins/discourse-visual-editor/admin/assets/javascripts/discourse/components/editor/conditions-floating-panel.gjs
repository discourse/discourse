// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionsTree from "./conditions-tree";

const DEFAULT_WIDTH = 480;
const DEFAULT_HEIGHT = 560;

/**
 * Detachable floating panel that hosts the conditions surface when
 * the inspector's `↗` button is clicked. Renders only when
 * `visualEditor.conditionsDetached` is true; mounted once at the
 * shell level so the panel survives tab switches.
 *
 * The panel is dragged via its header bar and resized via a corner
 * grip (vanilla `resize: both`). Position + size persist to
 * localStorage via the editor service so the layout survives
 * reloads. First-open positioning centres the panel over the canvas.
 *
 * z-index: above the editor shell (which uses `z("modal", "content")
 * - 200`) so the panel sits on top of the inspector and the canvas
 * but stays below DMenu's content layer.
 */
export default class ConditionsFloatingPanel extends Component {
  @service visualEditor;

  /**
   * Track resize via ResizeObserver — the `resize: both` corner grip
   * is browser-native and fires no DOM events, but a ResizeObserver
   * on the panel element catches the new size after each pointer-up.
   * We round to integers to keep the persisted rect tidy.
   */
  observeResize = modifier((element) => {
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const w = Math.round(entry.contentRect.width);
        const h = Math.round(entry.contentRect.height);
        const current = this.visualEditor.conditionsPanelRect ?? {};
        if (current.width === w && current.height === h) {
          continue;
        }
        const rect = element.getBoundingClientRect();
        this.visualEditor.updateConditionsPanelRect({
          x: Math.round(rect.left),
          y: Math.round(rect.top),
          width: w,
          height: h,
        });
      }
    });
    observer.observe(element);
    return () => observer.disconnect();
  });
  @tracked _dragging = false;
  _dragStart = null;

  _onDragMove = (event) => {
    if (!this._dragStart) {
      return;
    }
    const dx = event.clientX - this._dragStart.pointerX;
    const dy = event.clientY - this._dragStart.pointerY;
    const next = {
      x: Math.max(
        0,
        Math.min(
          window.innerWidth - this._dragStart.width,
          Math.round(this._dragStart.originX + dx)
        )
      ),
      y: Math.max(
        0,
        Math.min(
          window.innerHeight - this._dragStart.height,
          Math.round(this._dragStart.originY + dy)
        )
      ),
      width: Math.round(this._dragStart.width),
      height: Math.round(this._dragStart.height),
    };
    this.visualEditor.updateConditionsPanelRect(next);
  };

  _endDrag = () => {
    this._dragging = false;
    this._dragStart = null;
    document.removeEventListener("pointermove", this._onDragMove);
  };

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("pointermove", this._onDragMove);
  }

  get isOpen() {
    return this.visualEditor.isActive && this.visualEditor.conditionsDetached;
  }

  /**
   * Inline style for the panel, computed from the persisted rect or
   * defaulting to a centred 480x560 frame. Recomputed on every read
   * so drag updates flow through the tracking system.
   */
  get panelStyle() {
    const rect = this.visualEditor.conditionsPanelRect;
    const w = rect?.width ?? DEFAULT_WIDTH;
    const h = rect?.height ?? DEFAULT_HEIGHT;
    const x = rect?.x ?? Math.max(0, Math.floor((window.innerWidth - w) / 2));
    const y = rect?.y ?? Math.max(0, Math.floor((window.innerHeight - h) / 3));
    return trustHTML(
      `left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px;`
    );
  }

  @action
  startDrag(event) {
    // Ignore drags initiated from the buttons inside the header —
    // those should fire their own click handlers instead.
    if (event.target.closest("button")) {
      return;
    }
    event.preventDefault();
    const rect = event.currentTarget
      .closest(".visual-editor-conditions-floating")
      .getBoundingClientRect();
    this._dragStart = {
      pointerX: event.clientX,
      pointerY: event.clientY,
      originX: rect.left,
      originY: rect.top,
      width: rect.width,
      height: rect.height,
    };
    this._dragging = true;
    document.addEventListener("pointermove", this._onDragMove);
    document.addEventListener("pointerup", this._endDrag, { once: true });
  }

  @action
  redock() {
    this.visualEditor.closeConditionsPanel();
  }

  <template>
    {{#if this.isOpen}}
      <div
        class="visual-editor-conditions-floating"
        style={{this.panelStyle}}
        role="dialog"
        aria-label={{i18n
          "visual_editor.inspector.conditions.floating_panel_title"
        }}
        {{this.observeResize}}
      >
        <div
          class="visual-editor-conditions-floating__header"
          {{! template-lint-disable no-pointer-down-event-binding }}
          {{! Drag-to-move needs pointerdown to capture the initial
              cursor offset and start tracking pointermove. pointerup
              is the wrong half of the drag interaction. }}
          {{on "pointerdown" this.startDrag}}
        >
          <span class="visual-editor-conditions-floating__title">
            {{dIcon "filter"}}
            <span>{{i18n
                "visual_editor.inspector.conditions.floating_panel_title"
              }}</span>
          </span>
          <div class="visual-editor-conditions-floating__actions">
            <button
              type="button"
              class="visual-editor-conditions-floating__btn"
              title={{i18n "visual_editor.inspector.conditions.redock_panel"}}
              {{on "click" this.redock}}
            >
              {{dIcon "down-left-and-up-right-to-center"}}
            </button>
          </div>
        </div>

        <div class="visual-editor-conditions-floating__body">
          <ConditionsTree />
        </div>
      </div>
    {{/if}}
  </template>
}
