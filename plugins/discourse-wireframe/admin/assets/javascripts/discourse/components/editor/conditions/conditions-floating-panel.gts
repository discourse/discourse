import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionsTree from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/conditions-tree";
import WireframeConditionsPanelService, {
  type ConditionsPanelRect,
} from "../../../services/wireframe-conditions-panel";
import type WireframeEditModeService from "../../../services/wireframe-edit-mode";

const DEFAULT_WIDTH = 480;
const DEFAULT_HEIGHT = 560;

/**
 * The pointer/frame anchor captured when a drag begins, used to
 * translate subsequent pointer moves into a new panel position.
 */
type PanelDragStart = {
  /** Initial horizontal pointer position. */
  pointerX: number;
  /** Initial vertical pointer position. */
  pointerY: number;
  /** Initial horizontal panel position. */
  originX: number;
  /** Initial vertical panel position. */
  originY: number;
  /** Panel width at drag start. */
  width: number;
  /** Panel height at drag start. */
  height: number;
};

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
  /** Stores floating-panel visibility and geometry. */
  @service declare wireframeConditionsPanel: WireframeConditionsPanelService;

  /** Reports whether the wireframe editor is active. */
  @service declare wireframeEditMode: WireframeEditModeService;

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
        const current = this.wireframeConditionsPanel.rect;
        if (current?.width === w && current.height === h) {
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

  /** Registers pointer handling without a template event suppression. */
  dragHandle = modifier((element: HTMLElement) => {
    element.addEventListener("pointerdown", this.startDrag);
    return () => element.removeEventListener("pointerdown", this.startDrag);
  });
  /** Pointer and panel geometry captured at drag start. */
  #dragStart: PanelDragStart | null = null;

  /**
   * Moves the panel while a header drag is active.
   *
   * @param event - Document pointer-move event.
   */
  #onDragMove: (event: PointerEvent) => void = (event) => {
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

  /** Ends the active header drag. */
  #endDrag: () => void = () => {
    this._dragging = false;
    this.#dragStart = null;
    document.removeEventListener("pointermove", this.#onDragMove);
  };

  /** Whether the panel header is currently being dragged. */
  @tracked _dragging: boolean = false;

  /** Removes document listeners when the panel component is destroyed. */
  willDestroy(): void {
    super.willDestroy();
    document.removeEventListener("pointermove", this.#onDragMove);
  }

  /** Whether the detached panel should be rendered. */
  get isOpen(): boolean {
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
    const rect: Readonly<ConditionsPanelRect> | null =
      this.wireframeConditionsPanel.rect;
    const w = rect?.width ?? DEFAULT_WIDTH;
    const h = rect?.height ?? DEFAULT_HEIGHT;
    const x = rect?.x ?? Math.max(0, Math.floor((window.innerWidth - w) / 2));
    const y = rect?.y ?? Math.max(0, Math.floor((window.innerHeight - h) / 3));
    return trustHTML(
      `left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px;`
    );
  }

  /**
   * Begins dragging from the panel header.
   *
   * @param event - Header pointer-down event.
   */
  @action
  startDrag(event: PointerEvent): void {
    // Ignore drags initiated from the buttons inside the header —
    // those should fire their own click handlers instead.
    if (event.target instanceof Element && event.target.closest("button")) {
      return;
    }
    event.preventDefault();
    if (!(event.currentTarget instanceof HTMLElement)) {
      return;
    }
    const panel = event.currentTarget.closest(".wireframe-conditions-floating");
    if (!(panel instanceof HTMLElement)) {
      return;
    }
    const rect = panel.getBoundingClientRect();
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

  /** Returns the condition builder to the inspector. */
  @action
  redock(): void {
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
        <div class="wireframe-conditions-floating__header" {{this.dragHandle}}>
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
