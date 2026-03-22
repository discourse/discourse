import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import Controls from "./controls";
import { createReteEditor } from "./rete-editor";
import StatusToggle from "./status-toggle";

const PAUSED_SHORTCUTS = ["-", "="];

export default class WorkflowCanvas extends Component {
  @service keyboardShortcuts;

  @tracked isLoading = true;
  @tracked contextMenu = null;
  @tracked zoom = 1;
  reteApi = null;

  #ZOOM_STEP = 0.05;
  #ZOOM_MIN = 0.25;
  #ZOOM_MAX = 4;

  @tracked _selectedNodeIds = new Set();
  _isFirstSync = true;

  willDestroy() {
    super.willDestroy();
    this.reteApi?.destroy();
    try {
      this.keyboardShortcuts?.unpause(PAUSED_SHORTCUTS);
    } catch {
      // keyboard shortcuts may not be fully initialized
    }
  }

  @action
  async setupCanvas(element) {
    this.keyboardShortcuts.pause(PAUSED_SHORTCUTS);

    this.canvasElement = element;
    this.containerElement = element.querySelector(
      ".workflows-canvas__rete-container"
    );

    this.reteApi = await createReteEditor(this.containerElement, {
      iconHTML,
      callbacks: {
        onNodeDragged: (clientId, position) => {
          this.args.onUpdateNodePosition?.(clientId, position);
        },
        onNodePicked: (clientId) => {
          this._selectedNodeIds = new Set([clientId]);
        },
        onCanvasPointerDown: () => {
          this._selectedNodeIds = new Set();
          this.closeContextMenu();
          this.args.onCloseNodePanel?.();
        },
        onNodeDragEnd: () => {
          this.args.onNodeDragEnd?.();
        },
        onConnectionCreated: (sourceClientId, sourceOutput, targetClientId) => {
          this.args.onCreateConnection?.(
            sourceClientId,
            sourceOutput,
            targetClientId
          );
        },
        onLoopAddNode: (loopNodeClientId) => {
          this.args.onOpenNodePanel?.({ loopNodeClientId });
        },
        onNodeDelete: (clientId) => {
          this.args.onRemoveNode?.(clientId);
        },
        onConnectionAddNode: (sourceClientId, sourceOutput, targetClientId) => {
          this.args.onOpenNodePanel?.({
            connectionSource: sourceClientId,
            connectionSourceOutput: sourceOutput,
            connectionTarget: targetClientId,
          });
        },
        onConnectionDelete: (sourceClientId, sourceOutput, targetClientId) => {
          this.args.onConnectionDelete?.(
            sourceClientId,
            sourceOutput,
            targetClientId
          );
        },
        onManualTrigger: async (clientId, btnEl) => {
          if (btnEl.disabled) {
            return;
          }
          btnEl.disabled = true;
          btnEl.classList.add("--running");
          try {
            await ajax(`/admin/plugins/discourse-workflows/executions.json`, {
              type: "POST",
              data: { trigger_node_id: clientId },
            });
          } finally {
            btnEl.disabled = false;
            btnEl.classList.remove("--running");
          }
        },
        onNodeDoubleClick: (clientId) => {
          this.args.onEditNode?.(clientId);
        },
        onZoomed: (k) => {
          this.zoom = k;
        },
      },
    });

    this.args.onAreaReady?.(this.reteApi.area);

    this.isLoading = false;
    await this.syncToRete();
    element.focus();
  }

  @action
  async syncToRete() {
    if (!this.reteApi) {
      return;
    }

    await this.reteApi.syncState(
      this.args.nodes || [],
      this.args.connections || []
    );

    if (this._isFirstSync) {
      this._isFirstSync = false;
      await this.reteApi.fitToView();
    }

    this.zoom = this.reteApi.getZoom();
  }

  get showEmptyState() {
    return !this.isLoading && (this.args.nodes || []).length === 0;
  }

  @action
  handleContextMenu(event) {
    event.preventDefault();
    this.closeContextMenu();

    if (!this.reteApi) {
      return;
    }

    // Check if right-click was on a node
    const nodeEl = event.target.closest(".workflow-rete-node");
    if (nodeEl) {
      const clientId = nodeEl.dataset.clientId;
      if (clientId && !this._selectedNodeIds.has(clientId)) {
        this._selectedNodeIds = new Set([clientId]);
      }
      this.contextMenu = {
        nodeId: clientId,
        screenX: event.clientX,
        screenY: event.clientY,
      };
      return;
    }

    // Canvas right-click → open node panel
    const rect = this.containerElement.getBoundingClientRect();
    this.args.onOpenNodePanel?.(
      this.#containerToSvg(event.clientX - rect.left, event.clientY - rect.top)
    );
  }

  #containerToSvg(localX, localY) {
    const { x, y, k } = this.reteApi.area.area.transform;
    return {
      svgX: (localX - x) / k,
      svgY: (localY - y) / k,
    };
  }

  #viewportCenter() {
    const rect = this.containerElement.getBoundingClientRect();
    return this.#containerToSvg(rect.width / 2, rect.height / 2);
  }

  @action
  openNodePanelAtCenter() {
    if (!this.reteApi || !this.containerElement) {
      return;
    }
    this.closeContextMenu();
    this.args.onOpenNodePanel?.(this.#viewportCenter());
  }

  @action
  closeContextMenu() {
    this.contextMenu = null;
  }

  @action
  contextMenuEditNode() {
    const nodeId = this.contextMenu.nodeId;
    this.closeContextMenu();
    this.args.onEditNode?.(nodeId);
  }

  @action
  contextMenuDeleteNode() {
    this.closeContextMenu();
    this.#deleteSelectedNodes();
  }

  #deleteSelectedNodes() {
    if (this._selectedNodeIds.size > 1) {
      this.args.onRemoveNodes?.([...this._selectedNodeIds]);
    } else if (this._selectedNodeIds.size === 1) {
      const [nodeId] = this._selectedNodeIds;
      this.args.onRemoveNode?.(nodeId);
    }
    this._selectedNodeIds = new Set();
  }

  // Keyboard

  @action
  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.closeContextMenu();
      this._selectedNodeIds = new Set();
      return;
    }

    const isInInput =
      event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA";

    if (!isInInput && (event.key === "Delete" || event.key === "Backspace")) {
      this.#deleteSelectedNodes();
      return;
    }

    if (isInInput) {
      return;
    }

    const isMeta = event.metaKey || event.ctrlKey;
    const key = event.key.toLowerCase();
    if (isMeta && key === "z" && !event.shiftKey) {
      event.preventDefault();
      this.args.onUndo?.();
      return;
    }
    if (isMeta && ((key === "z" && event.shiftKey) || key === "y")) {
      event.preventDefault();
      this.args.onRedo?.();
      return;
    }

    switch (event.key) {
      case "+":
      case "=":
        this.zoomIn();
        break;
      case "-":
        this.zoomOut();
        break;
      default:
        if (event.code === "Digit1") {
          this.fitToView();
        }
        break;
    }
  }

  // Zoom controls

  async #applyZoom(delta) {
    if (!this.reteApi) {
      return;
    }
    const currentK = this.reteApi.area.area.transform.k;
    const newK = Math.max(
      this.#ZOOM_MIN,
      Math.min(this.#ZOOM_MAX, currentK + delta)
    );
    await this.reteApi.zoomAtViewportCenter(newK);
    this.zoom = this.reteApi.getZoom();
  }

  @action
  async zoomIn() {
    await this.#applyZoom(this.#ZOOM_STEP);
  }

  @action
  async zoomOut() {
    await this.#applyZoom(-this.#ZOOM_STEP);
  }

  @action
  async fitToView() {
    if (!this.reteApi) {
      return;
    }
    await this.reteApi.fitToView();
    this.zoom = this.reteApi.getZoom();
  }

  @action
  async autoLayout() {
    if (!this.reteApi) {
      return;
    }
    const positions = await this.reteApi.autoArrange();
    this.args.onAutoLayout?.(positions);
    await this.reteApi.fitToView();
    this.zoom = this.reteApi.getZoom();
  }

  get contextMenuStyle() {
    if (!this.contextMenu || !this.canvasElement) {
      return "";
    }
    const rect = this.canvasElement.getBoundingClientRect();
    const left = this.contextMenu.screenX - rect.left;
    const top = this.contextMenu.screenY - rect.top;
    return trustHTML(`left: ${left}px; top: ${top}px`);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="workflows-canvas"
      tabindex="0"
      {{on "keydown" this.handleKeyDown}}
      {{on "contextmenu" this.handleContextMenu}}
      {{didInsert this.setupCanvas}}
      {{didUpdate this.syncToRete @nodes @connections}}
    >
      {{#if this.isLoading}}
        <div class="workflows-canvas__spinner-overlay">
          <div class="spinner"></div>
        </div>
      {{/if}}

      {{#if this.showEmptyState}}
        <div class="workflows-canvas__empty-state">
          <button
            type="button"
            class="workflows-canvas__empty-state-trigger"
            {{on "click" this.openNodePanelAtCenter}}
          >
            <span class="workflows-canvas__empty-state-tile">
              {{icon "plus"}}
            </span>
            <span class="workflows-canvas__empty-state-label">
              {{i18n "discourse_workflows.add_node.first_step"}}
            </span>
          </button>
        </div>
      {{/if}}

      <div class="workflows-canvas__rete-container"></div>

      <Controls
        @onUndo={{@onUndo}}
        @onRedo={{@onRedo}}
        @canUndo={{@canUndo}}
        @canRedo={{@canRedo}}
        @onZoomIn={{this.zoomIn}}
        @onZoomOut={{this.zoomOut}}
        @onFitToView={{this.fitToView}}
        @onAutoLayout={{this.autoLayout}}
      />

      {{#if @onToggleEnabled}}
        <StatusToggle @enabled={{@enabled}} @onToggle={{@onToggleEnabled}} />
      {{/if}}

      {{#if @onOpenNodePanel}}
        <DButton
          @action={{this.openNodePanelAtCenter}}
          @icon="plus"
          class="btn-default workflows-canvas__add-node-btn"
        />
      {{/if}}

      {{#if this.contextMenu}}
        <div
          class="workflows-canvas__context-menu"
          style={{this.contextMenuStyle}}
        >
          <DButton
            @action={{this.contextMenuEditNode}}
            @icon="pencil"
            @translatedLabel={{i18n "discourse_workflows.edit"}}
            class="btn-transparent workflows-canvas__context-menu-item"
          />
          <DButton
            @action={{this.contextMenuDeleteNode}}
            @icon="trash-can"
            @translatedLabel={{i18n "discourse_workflows.delete"}}
            class="btn-transparent btn-danger workflows-canvas__context-menu-item"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
