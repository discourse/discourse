import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionsTree from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/conditions-tree";
import type WireframeConditionsPanel from "../../../services/wireframe-conditions-panel";
import type WireframeEditMode from "../../../services/wireframe-edit-mode";

const DEFAULT_WIDTH = 480;
const DEFAULT_HEIGHT = 560;

/**
 * The floating panel's on-screen position and size. The conditions-panel
 * service persists this to localStorage but seeds its tracked state with
 * `rect: null`, so it can only surface a degenerate `{} | null` type;
 * this is the real runtime shape, applied at the read boundary below.
 */
interface PanelRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * The pointer/frame anchor captured when a drag begins, used to
 * translate subsequent pointer moves into a new panel position.
 */
interface PanelDragStart {
  pointerX: number;
  pointerY: number;
  originX: number;
  originY: number;
  width: number;
  height: number;
}

/**
 * Detachable floating panel that hosts the conditions surface when
 * the inspector's `↗` button is clicked. Renders only when
 * `wireframeConditionsPanel.detached` is true; mounted once at the
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
  @service declare wireframeConditionsPanel: WireframeConditionsPanel;
  @service declare wireframeEditMode: WireframeEditMode;

  /**
   * Track resize via ResizeObserver — the `resize: both` corner grip
   * is browser-native and fires no DOM events, but a ResizeObserver
   * on the panel element catches the new size after each pointer-up.
   * We round to integers to keep the persisted rect tidy.
   */
  observeResize = modifier((element: HTMLElement) => {
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const w = Math.round(entry.contentRect.width);
        const h = Math.round(entry.contentRect.height);
        const current = (this.wireframeConditionsPanel.rect ??
          {}) as Partial<PanelRect>;
        if (current.width === w && current.height === h) {
          continue;
        }
        const rect = element.getBoundingClientRect();
        this.wireframeConditionsPanel.updateRect({
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
  #dragStart: PanelDragStart | null = null;
  #onDragMove = (event: PointerEvent) => {
    const dragStart = this.#dragStart;
    if (!dragStart) {
      return;
    }
    const dx = event.clientX - dragStart.pointerX;
    const dy = event.clientY - dragStart.pointerY;
    const next = {
      x: Math.max(
        0,
        Math.min(
          window.innerWidth - dragStart.width,
          Math.round(dragStart.originX + dx)
        )
      ),
      y: Math.max(
        0,
        Math.min(
          window.innerHeight - dragStart.height,
          Math.round(dragStart.originY + dy)
        )
      ),
      width: Math.round(dragStart.width),
      height: Math.round(dragStart.height),
    };
    this.wireframeConditionsPanel.updateRect(next);
  };
  #endDrag = () => {
    this._dragging = false;
    this.#dragStart = null;
    document.removeEventListener("pointermove", this.#onDragMove);
  };
  @tracked _dragging = false;

  willDestroy() {
    super.willDestroy();
    document.removeEventListener("pointermove", this.#onDragMove);
  }

  get isOpen() {
    return (
      this.wireframeEditMode.active && this.wireframeConditionsPanel.detached
    );
  }

  /**
   * Inline style for the panel, computed from the persisted rect or
   * defaulting to a centred 480x560 frame. Recomputed on every read
   * so drag updates flow through the tracking system.
   */
  get panelStyle(): TrustedHTML {
    const rect = this.wireframeConditionsPanel.rect as PanelRect | null;
    const w = rect?.width ?? DEFAULT_WIDTH;
    const h = rect?.height ?? DEFAULT_HEIGHT;
    const x = rect?.x ?? Math.max(0, Math.floor((window.innerWidth - w) / 2));
    const y = rect?.y ?? Math.max(0, Math.floor((window.innerHeight - h) / 3));
    return trustHTML(
      `left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px;`
    );
  }

  @action
  startDrag(event: PointerEvent) {
    // Ignore drags initiated from the buttons inside the header —
    // those should fire their own click handlers instead.
    if ((event.target as HTMLElement).closest("button")) {
      return;
    }
    event.preventDefault();
    const rect = (event.currentTarget as HTMLElement)
      .closest(".wireframe-conditions-floating")!
      .getBoundingClientRect();
    this.#dragStart = {
      pointerX: event.clientX,
      pointerY: event.clientY,
      originX: rect.left,
      originY: rect.top,
      width: rect.width,
      height: rect.height,
    };
    this._dragging = true;
    document.addEventListener("pointermove", this.#onDragMove);
    document.addEventListener("pointerup", this.#endDrag, { once: true });
  }

  @action
  redock() {
    this.wireframeConditionsPanel.close();
  }

  <template>
    {{#if this.isOpen}}
      <div
        class="wireframe-conditions-floating"
        style={{this.panelStyle}}
        role="dialog"
        aria-label={{i18n
          "wireframe.inspector.conditions.floating_panel_title"
        }}
        {{this.observeResize}}
      >
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <div
          class="wireframe-conditions-floating__header"
          {{! Drag-to-move needs pointerdown to capture the initial
              cursor offset and start tracking pointermove. pointerup
              is the wrong half of the drag interaction. }}
          {{on "pointerdown" this.startDrag}}
        >
          <span class="wireframe-conditions-floating__title">
            {{dIcon "filter"}}
            <span>{{i18n
                "wireframe.inspector.conditions.floating_panel_title"
              }}</span>
          </span>
          <div class="wireframe-conditions-floating__actions">
            <DButton
              class="wireframe-conditions-floating__btn"
              @icon="down-left-and-up-right-to-center"
              @title="wireframe.inspector.conditions.redock_panel"
              @action={{this.redock}}
            />
          </div>
        </div>

        <div class="wireframe-conditions-floating__body">
          <ConditionsTree />
        </div>
      </div>
    {{/if}}
  </template>
}
