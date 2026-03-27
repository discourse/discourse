import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import { loadNodeTypes } from "../../../lib/workflows/node-types";
import StickyNote from "../../../models/sticky-note";
import Controls from "./controls";
import { createReteEditor } from "./rete-editor";
import StickyNotesLayer from "./sticky-notes-layer";
import WorkflowNode from "./workflow-node";

const PAUSED_SHORTCUTS = ["-", "="];

export default class WorkflowCanvas extends Component {
  @service keyboardShortcuts;
  @service menu;
  @service router;
  @service toasts;

  @tracked isLoading = true;
  @tracked contextMenu = null;
  @tracked zoom = 1;
  @tracked reteApi = null;
  @tracked areaTransform = { x: 0, y: 0, k: 1 };
  @tracked manuallyTriggerableTypes = new Set();

  #ZOOM_STEP = 0.05;
  #ZOOM_MIN = 0.25;
  #ZOOM_MAX = 4;

  #handleDocumentKeyDown = (event) => {
    const isInInput =
      event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA";
    if (isInInput) {
      return;
    }

    const isMeta = event.metaKey || event.ctrlKey;
    const key = event.key.toLowerCase();

    if (isMeta && key === "z" && !event.shiftKey) {
      event.preventDefault();
      this.args.onUndo?.();
    } else if (isMeta && ((key === "z" && event.shiftKey) || key === "y")) {
      event.preventDefault();
      this.args.onRedo?.();
    } else if (isMeta && key === "c") {
      this.#copyStickyNote();
    } else if (isMeta && key === "v") {
      this.#pasteStickyNote();
    }
  };

  @tracked _selectedNodeIds = new Set();
  @tracked _selectedStickyNoteId = null;
  _copiedStickyNote = null;
  _isFirstSync = true;

  willDestroy() {
    super.willDestroy();
    this.reteApi?.destroy();
    document.removeEventListener("keydown", this.#handleDocumentKeyDown);
    try {
      this.keyboardShortcuts?.unpause(PAUSED_SHORTCUTS);
    } catch {
      // keyboard shortcuts may not be fully initialized
    }
  }

  @action
  async setupCanvas(element) {
    this.keyboardShortcuts.pause(PAUSED_SHORTCUTS);
    document.addEventListener("keydown", this.#handleDocumentKeyDown);

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
          this._selectedStickyNoteId = null;
        },
        onCanvasPointerDown: () => {
          this._selectedNodeIds = new Set();
          this._selectedStickyNoteId = null;
          this.closeContextMenu();
          this.menu.close("workflows-canvas-menu");
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
        onManualTrigger: async (clientId) => {
          const result = await ajax(
            `/admin/plugins/discourse-workflows/executions.json`,
            {
              type: "POST",
              data: { trigger_node_id: clientId },
            }
          );
          const { workflow_id, id } = result.execution;
          this.toasts.success({
            data: {
              message: i18n("discourse_workflows.manual_trigger.triggered"),
              actions: [
                {
                  label: i18n(
                    "discourse_workflows.manual_trigger.view_execution"
                  ),
                  class: "btn-primary btn-small",
                  action: ({ close }) => {
                    close();
                    this.router.transitionTo(
                      "adminPlugins.show.discourse-workflows.show.executions.show",
                      workflow_id,
                      id
                    );
                  },
                },
              ],
            },
          });
        },
        onNodeDoubleClick: (clientId) => {
          this.args.onEditNode?.(clientId);
        },
        onZoomed: (k) => {
          this.zoom = k;
        },
      },
    });

    this.reteApi.area.addPipe((context) => {
      if (
        context.type === "translated" ||
        context.type === "zoomed" ||
        context.type === "nodetranslated"
      ) {
        this.#syncAreaTransform();
      }
      return context;
    });

    this.args.onAreaReady?.(this.reteApi.area);

    const types = await loadNodeTypes();
    this.manuallyTriggerableTypes = new Set(
      (types || [])
        .filter((t) => t.manually_triggerable)
        .map((t) => t.identifier)
    );

    this.isLoading = false;
    await this.syncToRete();
    this.#syncAreaTransform();
    element.focus();
  }

  #syncAreaTransform() {
    if (!this.reteApi) {
      return;
    }
    const { x, y, k } = this.reteApi.area.area.transform;
    this.areaTransform = { x, y, k };
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

  get nodeEntries() {
    return this.reteApi?.renderer?.nodeEntryList ?? [];
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

    // Canvas right-click → show canvas context menu
    const rect = this.containerElement.getBoundingClientRect();
    const svgPos = this.#containerToSvg(
      event.clientX - rect.left,
      event.clientY - rect.top
    );
    this.contextMenu = {
      isCanvas: true,
      svgPos,
      screenX: event.clientX,
      screenY: event.clientY,
    };
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

  @action
  contextMenuAddNode() {
    const svgPos = this.contextMenu?.svgPos;
    this.closeContextMenu();
    if (svgPos) {
      this.args.onOpenNodePanel?.(svgPos);
    }
  }

  @action
  contextMenuAddStickyNote() {
    const svgPos = this.contextMenu?.svgPos;
    this.closeContextMenu();
    if (svgPos) {
      this.args.onAddStickyNote?.(svgPos);
    }
  }

  @action
  selectStickyNote(clientId) {
    this._selectedStickyNoteId = clientId;
    this._selectedNodeIds = new Set();
  }

  #copyStickyNote() {
    if (!this._selectedStickyNoteId) {
      return;
    }
    const note = (this.args.stickyNotes || []).find(
      (n) => n.clientId === this._selectedStickyNoteId
    );
    if (note) {
      this._copiedStickyNote = structuredClone(note);
    }
  }

  #pasteStickyNote() {
    if (!this._copiedStickyNote) {
      return;
    }
    const offset = 20;
    const newClientId = this.args.onPasteStickyNote?.({
      position: {
        x: this._copiedStickyNote.position.x + offset,
        y: this._copiedStickyNote.position.y + offset,
      },
      size: { ...this._copiedStickyNote.size },
      color: this._copiedStickyNote.color,
      text: this._copiedStickyNote.text,
    });
    if (newClientId) {
      this._selectedStickyNoteId = newClientId;
      this._selectedNodeIds = new Set();
    }
  }

  @action
  addStickyNoteAtCenter(closeFn) {
    closeFn?.();
    if (!this.reteApi || !this.containerElement) {
      return;
    }
    this.closeContextMenu();
    const center = this.#viewportCenter();
    this.args.onAddStickyNote?.({ svgX: center.svgX, svgY: center.svgY });
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
      this._selectedStickyNoteId = null;
      return;
    }

    const isInInput =
      event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA";

    if (!isInInput && (event.key === "Delete" || event.key === "Backspace")) {
      if (this._selectedStickyNoteId) {
        this.args.onStickyNoteDelete?.(this._selectedStickyNoteId);
        this._selectedStickyNoteId = null;
      } else {
        this.#deleteSelectedNodes();
      }
      return;
    }

    if (isInInput) {
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

  @action
  exportNodes(closeFn) {
    closeFn();

    const nodes = (this.args.nodes || []).map((n) => ({
      type: n.type,
      type_version: n.type_version,
      name: n.name,
      configuration: n.configuration || {},
      position: n.position || null,
    }));

    const clientIdToIndex = new Map();
    (this.args.nodes || []).forEach((n, i) => {
      clientIdToIndex.set(n.clientId, i);
    });

    const connections = (this.args.connections || [])
      .filter(
        (c) =>
          clientIdToIndex.has(c.sourceClientId) &&
          clientIdToIndex.has(c.targetClientId)
      )
      .map((c) => ({
        source_index: clientIdToIndex.get(c.sourceClientId),
        target_index: clientIdToIndex.get(c.targetClientId),
        source_output: c.sourceOutput || "main",
      }));

    const stickyNotes = (this.args.stickyNotes || []).map((n) => {
      const serialized = StickyNote.serialize(n);
      delete serialized.id;
      return serialized;
    });

    const payload = { version: 1, nodes, connections };
    if (stickyNotes.length > 0) {
      payload.sticky_notes = stickyNotes;
    }
    const data = JSON.stringify(payload, null, 2);
    const date = new Date().toISOString().slice(0, 10);
    const file = new File([data], `workflow-nodes-${date}.json`, {
      type: "application/json",
    });

    const a = document.createElement("a");
    a.style.display = "none";
    a.href = URL.createObjectURL(file);
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(a.href);
  }

  @action
  triggerImport(closeFn) {
    closeFn();
    this._fileInput?.click();
  }

  @action
  registerFileInput(element) {
    this._fileInput = element;
  }

  @action
  async handleFileSelected(event) {
    const file = event.target.files?.[0];
    event.target.value = "";

    if (!file) {
      return;
    }

    try {
      const text = await file.text();
      const data = JSON.parse(text);

      if (!data || typeof data.version !== "number") {
        this.toasts.error({
          data: { message: i18n("discourse_workflows.canvas.import_error") },
        });
        return;
      }

      if (data.version !== 1) {
        this.toasts.error({
          data: {
            message: i18n("discourse_workflows.canvas.import_version_error"),
          },
        });
        return;
      }

      if (!Array.isArray(data.nodes) || data.nodes.length === 0) {
        this.toasts.error({
          data: { message: i18n("discourse_workflows.canvas.import_error") },
        });
        return;
      }

      const newNodes = data.nodes.map((n) => ({
        clientId: crypto.randomUUID(),
        type: n.type,
        type_version: n.type_version,
        name: n.name,
        configuration: n.configuration || {},
        position: n.position || null,
      }));

      const newConnections = (data.connections || [])
        .filter(
          (c) =>
            c.source_index >= 0 &&
            c.source_index < newNodes.length &&
            c.target_index >= 0 &&
            c.target_index < newNodes.length
        )
        .map((c) => ({
          sourceClientId: newNodes[c.source_index].clientId,
          targetClientId: newNodes[c.target_index].clientId,
          sourceOutput: c.source_output || "main",
        }));

      const newStickyNotes = (data.sticky_notes || []).map((n) =>
        StickyNote.create(n)
      );

      this.args.onImportNodes?.(newNodes, newConnections, newStickyNotes);
    } catch {
      this.toasts.error({
        data: { message: i18n("discourse_workflows.canvas.import_error") },
      });
    }
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

      <StickyNotesLayer
        @stickyNotes={{@stickyNotes}}
        @selectedStickyNoteId={{this._selectedStickyNoteId}}
        @areaTransform={{this.areaTransform}}
        @onSelect={{this.selectStickyNote}}
        @onDragStart={{@onStickyNoteDragStart}}
        @onMove={{@onStickyNoteMove}}
        @onResize={{@onStickyNoteResize}}
        @onUpdateText={{@onStickyNoteUpdateText}}
        @onChangeColor={{@onStickyNoteChangeColor}}
        @onDelete={{@onStickyNoteDelete}}
        @onDragEnd={{@onNodeDragEnd}}
      />

      <div class="workflows-canvas__rete-container"></div>

      {{#each this.nodeEntries as |entry|}}
        {{#in-element entry.element insertBefore=null}}
          <WorkflowNode
            @node={{entry.node}}
            @onDelete={{this.reteApi.renderer.onNodeDelete}}
            @onManualTrigger={{this.reteApi.renderer.onManualTrigger}}
            @onSocketRendered={{this.reteApi.renderer.onSocketRendered}}
            @manuallyTriggerableTypes={{this.manuallyTriggerableTypes}}
          />
        {{/in-element}}
      {{/each}}

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

      <input
        type="file"
        accept=".json"
        class="hidden"
        {{didInsert this.registerFileInput}}
        {{on "change" this.handleFileSelected}}
      />

      {{#if @onOpenNodePanel}}
        <div class="workflows-canvas__toolbar-top-right">
          <DButton
            @action={{this.openNodePanelAtCenter}}
            @icon="plus"
            class="btn-default workflows-canvas__add-node-btn"
          />

          <DMenu
            @identifier="workflows-canvas-menu"
            @icon="ellipsis-vertical"
            class="btn-default workflows-canvas__menu-btn"
          >
            <:content as |args|>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{fn this.addStickyNoteAtCenter args.close}}
                    @icon="note-sticky"
                    @translatedLabel={{i18n
                      "discourse_workflows.sticky_note.add"
                    }}
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.exportNodes args.close}}
                    @icon="download"
                    @translatedLabel={{i18n
                      "discourse_workflows.canvas.export_nodes"
                    }}
                    @disabled={{this.showEmptyState}}
                    class="btn-transparent"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn this.triggerImport args.close}}
                    @icon="upload"
                    @translatedLabel={{i18n
                      "discourse_workflows.canvas.import_nodes"
                    }}
                    class="btn-transparent"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      {{/if}}

      {{#if this.contextMenu}}
        <div
          class="workflows-canvas__context-menu"
          style={{this.contextMenuStyle}}
        >
          {{#if this.contextMenu.isCanvas}}
            <DButton
              @action={{this.contextMenuAddNode}}
              @icon="plus"
              @translatedLabel={{i18n "discourse_workflows.canvas.add_step"}}
              class="btn-transparent workflows-canvas__context-menu-item"
            />
            <DButton
              @action={{this.contextMenuAddStickyNote}}
              @icon="note-sticky"
              @translatedLabel={{i18n "discourse_workflows.sticky_note.add"}}
              class="btn-transparent workflows-canvas__context-menu-item"
            />
          {{else}}
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
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
