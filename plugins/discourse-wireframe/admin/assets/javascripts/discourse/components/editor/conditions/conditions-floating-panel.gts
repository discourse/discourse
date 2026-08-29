import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";
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
 * z-index: above the editor shell (which uses
 * `z("modal", "content") - 200`) so the panel sits on top of the inspector and the canvas
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

  /** The panel's rect when the header was pressed; `null` outside a drag. */
  #dragStart: ConditionsPanelRect | null = null;

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
   * The rect the panel is drawn at: the persisted one, or the centred
   * default `panelStyle` falls back to.
   */
  get #currentRect(): ConditionsPanelRect {
    const rect = this.wireframeConditionsPanel.rect;
    const width = rect?.width ?? DEFAULT_WIDTH;
    const height = rect?.height ?? DEFAULT_HEIGHT;
    return {
      x: rect?.x ?? Math.max(0, Math.floor((window.innerWidth - width) / 2)),
      y: rect?.y ?? Math.max(0, Math.floor((window.innerHeight - height) / 3)),
      width,
      height,
    };
  }

  /**
   * Begins dragging from the panel header. A press on one of the header's
   * buttons is theirs, not a drag.
   *
   * @param event - Header pointer-down event.
   * @returns `false` to leave the press to the button under it.
   */
  @action
  onDragStart(event: PointerEvent): boolean | void {
    if (event.target instanceof Element && event.target.closest("button")) {
      return false;
    }
    this.#dragStart = this.#currentRect;
  }

  /**
   * Moves the panel by the pointer's travel, kept inside the viewport.
   *
   * @param _event - The pointer event.
   * @param info - The gesture geometry.
   */
  @action
  onDrag(_event: PointerEvent, info: DPointerDragInfo): void {
    const start = this.#dragStart;
    if (!start) {
      return;
    }
    this.wireframeConditionsPanel.updateRect({
      x: Math.max(
        0,
        Math.min(
          window.innerWidth - start.width,
          Math.round(start.x + info.delta.x)
        )
      ),
      y: Math.max(
        0,
        Math.min(
          window.innerHeight - start.height,
          Math.round(start.y + info.delta.y)
        )
      ),
      width: Math.round(start.width),
      height: Math.round(start.height),
    });
  }

  @action
  onDragEnd(): void {
    this.#dragStart = null;
  }

  /** A gesture the browser took away puts the panel back where it began. */
  @action
  onDragCancel(): void {
    const start = this.#dragStart;
    this.#dragStart = null;
    if (start) {
      this.wireframeConditionsPanel.updateRect(start);
    }
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
        <div
          class="wireframe-conditions-floating__header"
          {{dPointerDrag
            onDragStart=this.onDragStart
            onDrag=this.onDrag
            onDragEnd=this.onDragEnd
            onDragCancel=this.onDragCancel
            draggingClass="--dragging"
            bodyClass="wf-conditions-panel-dragging"
            touchAction="none"
          }}
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
