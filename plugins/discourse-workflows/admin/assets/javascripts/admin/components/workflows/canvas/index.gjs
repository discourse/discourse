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
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import CanvasContextMenu from "./canvas-context-menu";
import { exportWorkflowToFile, parseWorkflowImport } from "./canvas-file-io";
import { setupCanvasKeyboard } from "./canvas-keyboard";
import { runManualTrigger } from "./canvas-manual-trigger";
import {
  buildStickyNoteTranslateHandler,
  computeStickyNoteRects,
} from "./canvas-sticky-notes";
import ConnectionToolbar from "./connection-toolbar";
import Controls from "./controls";
import { createReteEditor } from "./rete-editor";
import StickyNoteComponent from "./sticky-note";
import WorkflowNode from "./workflow-node";

const SVG_STYLE = trustHTML(
  "overflow:visible;position:absolute;pointer-events:none;width:9999px;height:9999px"
);
const SVG_STYLE_Z0 = trustHTML(
  "overflow:visible;position:absolute;pointer-events:none;width:9999px;height:9999px;z-index:0"
);

export default class WorkflowCanvas extends Component {
  @service keyboardShortcuts;
  @service menu;
  @service router;
  @service workflowsNodeTypes;
  @service toasts;

  @tracked isLoading = true;
  @tracked rete = null;
  @tracked areaTransform = { x: 0, y: 0, k: 1 };
  @tracked workflowEnabledOverride = null;
  @tracked selectionVersion = 0;
  copiedEntities = { nodes: [], stickyNotes: [] };
  pasteOffset = 0;
  isFirstSync = true;
  lastAutoArrangeRequest = 0;
  didHydrateInitialAutoLayout = false;
  #hasSetupStarted = false;
  #pendingSync = false;
  #syncTask = null;
  #ZOOM_STEP = 0.1;
  #ZOOM_MIN = 0.25;
  #ZOOM_MAX = 4;

  willDestroy() {
    super.willDestroy();
    this.rete?.destroy();
    this.keyboard?.teardown();
  }

  get workflowEnabled() {
    return this.workflowEnabledOverride ?? this.args.workflowEnabled;
  }

  @action
  isStickyNoteSelected(clientId) {
    this.selectionVersion;
    return this.rete?.isStickyNoteSelected(clientId) ?? false;
  }

  @action
  async toggleEnabled() {
    const newValue = !this.workflowEnabled;
    this.workflowEnabledOverride = newValue;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              name: this.args.workflowName,
              enabled: newValue,
            },
          },
        }
      );
      if (this.args.workflow) {
        this.args.workflow.enabled = newValue;
      }
    } catch {
      this.workflowEnabledOverride = !newValue;
    }
  }

  @action
  registerCanvas(element) {
    this.canvasElement = element;
    this.#maybeSetupCanvas();
  }

  @action
  registerContainer(element) {
    this.containerElement = element;
    this.#maybeSetupCanvas();
  }

  #keyboardActions() {
    return {
      onUndo: () => this.args.onUndo?.(),
      onRedo: () => this.args.onRedo?.(),
      onCopy: () => this.#copy(),
      onPaste: () => this.#paste(),
      onDelete: () => this.deleteSelected(),
      onEscape: () => {
        this.contextMenuApi?.close();
        this.rete?.selector.unselectAll();
        this.selectionVersion++;
      },
      onZoomIn: () => this.zoomIn(),
      onZoomOut: () => this.zoomOut(),
      onFitToView: () => this.fitToView(),
      onAutoLayout: () => this.autoLayout(),
    };
  }

  async #handleManualTrigger(clientId) {
    await runManualTrigger({
      node: this.#nodes().find((n) => n.clientId === clientId),
      clientId,
      toasts: this.toasts,
      router: this.router,
    });
  }

  #reteCallbacks() {
    return {
      onNodeDragged: (...a) => this.args.onUpdateNodePosition?.(...a),
      onNodePicked: () => this.selectionVersion++,
      onCanvasPointerDown: () => {
        this.selectionVersion++;
        this.contextMenuApi?.close();
        this.menu.close("workflows-canvas-menu");
        this.args.onCloseNodePanel?.();
      },
      onNodeDragEnd: () => this.args.onNodeDragEnd?.(),
      onConnectionCreated: (...a) => this.args.onCreateConnection?.(...a),
      onNodeDelete: (clientId) => this.args.onRemoveNodes?.([clientId]),
      onManualTrigger: (clientId) => this.#handleManualTrigger(clientId),
      onNodeDoubleClick: (clientId) => this.args.onEditNode?.(clientId),
      onTransformChanged: (t) => (this.areaTransform = t),
    };
  }

  #nodes() {
    return this.args.nodes || [];
  }

  #connections() {
    return this.args.connections || [];
  }

  #stickyNoteRects() {
    return computeStickyNoteRects(this.args.stickyNotes);
  }

  #shouldHydrateInitialAutoLayout(nodes) {
    return (
      !this.didHydrateInitialAutoLayout && nodes.some((node) => !node.position)
    );
  }

  #consumeAutoArrangeRequest(autoArrangeRequest) {
    if (autoArrangeRequest <= this.lastAutoArrangeRequest) {
      return false;
    }

    this.lastAutoArrangeRequest = autoArrangeRequest;
    return true;
  }

  async #applyAutoArrange(callback) {
    const positions = await this.rete.autoArrange();
    callback?.(positions);
  }

  async #syncViewport(prevNodeCount, stickyNoteRects) {
    if (this.isFirstSync || this.rete.nodeCount !== prevNodeCount) {
      this.isFirstSync = false;
      await this.rete.fitToView(stickyNoteRects);
    }
  }

  async #performSync() {
    const snapshot = {
      nodes: this.#nodes(),
      connections: this.#connections(),
      stickyNoteRects: this.#stickyNoteRects(),
      autoArrangeRequest: this.args.autoArrangeRequest || 0,
    };
    const prevNodeCount = this.rete.nodeCount;

    await this.rete.syncState(snapshot.nodes, snapshot.connections);

    if (this.#shouldHydrateInitialAutoLayout(snapshot.nodes)) {
      this.didHydrateInitialAutoLayout = true;
      await this.#applyAutoArrange(this.args.onHydrateAutoLayout);
    }

    if (this.#consumeAutoArrangeRequest(snapshot.autoArrangeRequest)) {
      await this.#applyAutoArrange(this.args.onSyncAutoLayout);
    }

    await this.#syncViewport(prevNodeCount, snapshot.stickyNoteRects);
  }

  async #flushSyncQueue() {
    try {
      while (this.#pendingSync) {
        this.#pendingSync = false;
        await this.#performSync();
      }
    } finally {
      this.#syncTask = null;
    }
  }

  async #queueSync() {
    if (!this.rete) {
      return;
    }

    this.#pendingSync = true;

    if (!this.#syncTask) {
      this.#syncTask = this.#flushSyncQueue();
    }

    await this.#syncTask;
  }

  async #maybeSetupCanvas() {
    if (
      this.#hasSetupStarted ||
      !this.canvasElement ||
      !this.containerElement
    ) {
      return;
    }

    this.#hasSetupStarted = true;
    const element = this.canvasElement;
    this.keyboard = setupCanvasKeyboard(
      this.keyboardShortcuts,
      this.#keyboardActions(),
      element
    );

    const nodeTypes = await this.workflowsNodeTypes.load();

    this.rete = await createReteEditor(this.containerElement, {
      nodeTypes,
      callbacks: this.#reteCallbacks(),
    });

    this.args.onAreaReady?.(this.rete.area);

    await this.#queueSync();
    this.isLoading = false;
    element.focus();
  }

  @action
  async syncToRete() {
    await this.#queueSync();
  }

  get nodeEntries() {
    return this.rete?.renderer.nodeEntryList ?? [];
  }

  get connectionEntries() {
    return this.rete?.renderer.connectionEntryList ?? [];
  }

  get outputHandleEntries() {
    return this.rete?.renderer.outputHandleEntryList ?? [];
  }

  get areaContentElement() {
    return this.rete?.areaContentElement;
  }

  @action
  handleConnectionToolbarAdd(connectionInfo) {
    this.args.onOpenNodePanel?.({
      connectionSource: connectionInfo.sourceClientId,
      connectionSourceOutput: connectionInfo.sourceOutput,
      connectionTarget: connectionInfo.targetClientId,
    });
  }

  @action
  handleConnectionToolbarDelete(connectionInfo) {
    this.args.onConnectionDelete?.(
      connectionInfo.sourceClientId,
      connectionInfo.sourceOutput,
      connectionInfo.targetClientId
    );
  }

  @action
  handleLoopBackAdd(loopNodeClientId, e) {
    e.stopPropagation();
    e.preventDefault();
    this.args.onOpenNodePanel?.({ loopNodeClientId });
  }

  @action
  handleOutputHandleAdd(nodeClientId, outputKey, e) {
    e.stopPropagation();
    this.args.onOpenNodePanel?.({
      sourceClientId: nodeClientId,
      sourceOutput: outputKey,
    });
  }

  get showEmptyState() {
    return !this.isLoading && (this.args.nodes || []).length === 0;
  }

  @action
  registerContextMenu(api) {
    this.contextMenuApi = api;
  }

  @action
  handleContextMenu(event) {
    this.contextMenuApi?.open(event);
  }

  #invokeAtViewportCenter(callback) {
    if (!this.rete || !this.containerElement) {
      return;
    }
    this.contextMenuApi?.close();
    callback?.(this.rete.viewportCenter());
  }

  @action
  openNodePanelAtCenter() {
    this.#invokeAtViewportCenter(this.args.onOpenNodePanel);
  }

  @action
  async selectStickyNote(clientId) {
    await this.rete?.selectStickyNote(clientId, {
      onStickyNoteTranslate: buildStickyNoteTranslateHandler(
        this.args.stickyNotes,
        this.args.onStickyNoteMove
      ),
      onStickyNoteUnselect: () => {
        this.selectionVersion++;
      },
    });
    this.selectionVersion++;
  }

  #copy() {
    const selected = this.rete?.getSelectedIds();
    if (!selected) {
      return;
    }
    const { nodeIds, stickyNoteIds } = selected;
    const cloneMatching = (items, ids) =>
      (items || []).filter((n) => ids.has(n.clientId)).map(structuredClone);
    const nodes = cloneMatching(this.args.nodes, nodeIds);
    const stickyNotes = cloneMatching(this.args.stickyNotes, stickyNoteIds);
    if (nodes.length > 0 || stickyNotes.length > 0) {
      this.copiedEntities = { nodes, stickyNotes };
      this.pasteOffset = 0;
    }
  }

  #paste() {
    const { nodes, stickyNotes } = this.copiedEntities;
    if (nodes.length === 0 && stickyNotes.length === 0) {
      return;
    }
    this.pasteOffset += 20;
    const offset = this.pasteOffset;
    const shift = (items) =>
      items.map((item) => ({
        ...item,
        position: item.position
          ? { x: item.position.x + offset, y: item.position.y + offset }
          : null,
      }));
    this.args.onPasteEntities?.({
      nodes: shift(nodes),
      stickyNotes: shift(stickyNotes),
    });
  }

  @action
  addStickyNoteAtCenter(closeFn) {
    closeFn?.();
    this.#invokeAtViewportCenter(this.args.onAddStickyNote);
  }

  @action
  deleteStickyNote(clientId) {
    this.args.onRemoveSelected?.({
      nodeIds: [],
      stickyNoteIds: [clientId],
    });
    this.selectionVersion++;
  }

  @action
  async translateSelected(draggedClientId, dx, dy) {
    await this.rete?.translateSelectedEntities(
      draggedClientId,
      "sticky-note",
      dx,
      dy
    );
  }

  @action
  deleteSelected() {
    const selected = this.rete?.getSelectedIds();
    if (!selected) {
      return;
    }
    const { nodeIds, stickyNoteIds } = selected;
    if (nodeIds.size > 0 || stickyNoteIds.size > 0) {
      this.args.onRemoveSelected?.({
        nodeIds: [...nodeIds],
        stickyNoteIds: [...stickyNoteIds],
      });
      this.rete?.selector.unselectAll();
      this.selectionVersion++;
    }
  }

  async #applyZoom(delta) {
    if (!this.rete) {
      return;
    }
    const currentK = this.rete.transform.k;
    const newK = Math.max(
      this.#ZOOM_MIN,
      Math.min(this.#ZOOM_MAX, currentK + delta)
    );
    await this.rete.zoomAtViewportCenter(newK);
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
    if (!this.rete) {
      return;
    }
    await this.rete.fitToView(this.#stickyNoteRects());
  }

  @action
  async autoLayout() {
    if (!this.rete) {
      return;
    }
    const positions = await this.rete.autoArrange();
    this.args.onAutoLayout?.(positions);
    await this.rete.fitToView(this.#stickyNoteRects());
  }

  @action
  exportWorkflow(closeFn) {
    closeFn();
    exportWorkflowToFile(
      this.args.nodes,
      this.args.connections,
      this.args.stickyNotes
    );
  }

  @action
  openImportDialog(closeFn) {
    closeFn();
    this.fileInput?.click();
  }

  @action
  registerFileInput(element) {
    this.fileInput = element;
  }

  #showImportError(key = "import_error") {
    this.toasts.error({
      data: { message: i18n(`discourse_workflows.canvas.${key}`) },
    });
  }

  @action
  async handleFileSelected(event) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) {
      return;
    }
    try {
      const result = parseWorkflowImport(await file.text());
      if (result.error) {
        this.#showImportError(
          result.error === "version" ? "import_version_error" : "import_error"
        );
        return;
      }
      this.args.onImportNodes?.(
        result.nodes,
        result.connections,
        result.stickyNotes
      );
    } catch {
      this.#showImportError();
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}

    <div
      class="workflows-canvas"
      tabindex="0"
      {{on "contextmenu" this.handleContextMenu}}
      {{didInsert this.registerCanvas}}
      {{didUpdate this.syncToRete @nodes @connections @autoArrangeRequest}}
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

      <div
        class="workflows-canvas__rete-container"
        {{didInsert this.registerContainer}}
      ></div>

      {{#each this.nodeEntries as |entry|}}
        {{#in-element entry.element insertBefore=null}}
          <WorkflowNode
            @node={{entry.node}}
            @onDelete={{this.rete.renderer.onNodeDelete}}
            @onManualTrigger={{this.rete.renderer.onManualTrigger}}
            @onSocketRendered={{this.rete.renderer.onSocketRendered}}
            @workflowEnabled={{this.workflowEnabled}}
          />
        {{/in-element}}
      {{/each}}

      {{#each this.connectionEntries as |entry|}}
        {{#in-element entry.element insertBefore=null}}
          {{! template-lint-disable no-forbidden-elements }}
          {{#if entry.isLoopBack}}
            <svg class="workflow-loop-back" style={{SVG_STYLE}}>
              <path
                class="workflow-loop-back__path"
                fill="none"
                stroke="var(--primary-low-mid)"
                stroke-width="1.5"
                d={{entry.pathD}}
              />
              <polygon
                class="workflow-loop-back__arrow"
                fill="var(--primary-low-mid)"
                points={{entry.loopArrowPoints}}
              />
              <foreignObject
                class="workflow-loop-back__button-fo"
                width="28"
                height="28"
                x={{entry.loopButtonX}}
                y={{entry.loopButtonY}}
              >
                <button
                  type="button"
                  class="workflow-loop-back__add-btn"
                  {{on
                    "click"
                    (fn this.handleLoopBackAdd entry.loopNodeClientId)
                  }}
                >+</button>
              </foreignObject>
            </svg>
          {{else}}
            <svg
              class={{concatClass
                "workflow-connection"
                (if entry.isPseudo "--pseudo")
              }}
              style={{SVG_STYLE}}
            >
              <path
                class="workflow-connection__hit"
                fill="none"
                stroke="transparent"
                stroke-width="12"
                pointer-events="stroke"
                style="cursor:pointer"
                d={{entry.pathD}}
              />
              <path
                class="workflow-connection__visible"
                fill="none"
                stroke={{if
                  entry.isPseudo
                  "var(--tertiary)"
                  "var(--primary-low-mid)"
                }}
                stroke-width="1.5"
                stroke-dasharray={{if entry.isPseudo "6 3" ""}}
                opacity={{if entry.isPseudo "0.6" ""}}
                d={{entry.pathD}}
              />
              <path
                class="workflow-connection__arrow"
                d="M -9 -5 L 0 0 L -9 5 Z"
                fill={{if
                  entry.isPseudo
                  "var(--tertiary)"
                  "var(--primary-low-mid)"
                }}
                stroke={{if
                  entry.isPseudo
                  "var(--tertiary)"
                  "var(--primary-low-mid)"
                }}
                stroke-width="2"
                stroke-linejoin="round"
                transform={{entry.arrowTransform}}
              />
              {{#unless entry.isPseudo}}
                <foreignObject
                  class="workflow-connection__toolbar-fo"
                  width="48"
                  height="22"
                  x={{entry.toolbarX}}
                  y={{entry.toolbarY}}
                >
                  <ConnectionToolbar
                    @hitPathSelector=".workflow-connection__hit"
                    @foreignObjectSelector=".workflow-connection__toolbar-fo"
                    @svgElement={{entry.element}}
                    @onAdd={{fn
                      this.handleConnectionToolbarAdd
                      entry.connectionInfo
                    }}
                    @onDelete={{fn
                      this.handleConnectionToolbarDelete
                      entry.connectionInfo
                    }}
                  />
                </foreignObject>
              {{/unless}}
            </svg>
          {{/if}}
        {{/in-element}}
      {{/each}}

      {{#each this.outputHandleEntries as |entry|}}
        {{#in-element entry.areaElement insertBefore=null}}
          {{! template-lint-disable no-forbidden-elements }}
          <svg class="workflow-output-handle" style={{SVG_STYLE_Z0}}>
            <path
              fill="none"
              stroke="var(--primary-low-mid)"
              stroke-width="1.5"
              d={{entry.pathD}}
            />
            <foreignObject
              class="workflow-output-handle__button-fo"
              width="14"
              height="14"
              x={{entry.buttonX}}
              y={{entry.buttonY}}
            >
              <button
                type="button"
                class="workflow-output-handle__add-btn"
                {{on
                  "click"
                  (fn
                    this.handleOutputHandleAdd
                    entry.nodeClientId
                    entry.outputKey
                  )
                }}
              >
                {{icon "plus"}}
              </button>
            </foreignObject>
          </svg>
        {{/in-element}}
      {{/each}}

      {{#if this.areaContentElement}}
        {{#each @stickyNotes key="clientId" as |note|}}
          {{#in-element this.areaContentElement insertBefore=null}}
            <StickyNoteComponent
              @note={{note}}
              @isSelected={{this.isStickyNoteSelected note.clientId}}
              @zoom={{this.areaTransform.k}}
              @onSelect={{fn this.selectStickyNote note.clientId}}
              @onBeforeMutation={{@onStickyNoteBeforeMutation}}
              @onMove={{fn @onStickyNoteMove note.clientId}}
              @onResize={{fn @onStickyNoteResize note.clientId}}
              @onUpdateText={{fn @onStickyNoteUpdateText note.clientId}}
              @onChangeColor={{fn @onStickyNoteChangeColor note.clientId}}
              @onDelete={{fn this.deleteStickyNote note.clientId}}
              @onTranslateSelected={{fn this.translateSelected note.clientId}}
              @onAfterMutation={{@onNodeDragEnd}}
            />
          {{/in-element}}
        {{/each}}
      {{/if}}

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

      <label
        class={{concatClass
          "workflows-canvas__status"
          (if this.workflowEnabled "is-published" "is-draft")
        }}
      >
        {{i18n "discourse_workflows.enabled"}}
        <input
          type="checkbox"
          checked={{this.workflowEnabled}}
          {{on "click" this.toggleEnabled}}
          class="workflows-canvas__status-checkbox"
        />
      </label>

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
                    @action={{fn this.exportWorkflow args.close}}
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
                    @action={{fn this.openImportDialog args.close}}
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

      <CanvasContextMenu
        @canvasElement={{this.canvasElement}}
        @containerElement={{this.containerElement}}
        @rete={{this.rete}}
        @onEditNode={{@onEditNode}}
        @onDeleteSelected={{this.deleteSelected}}
        @onOpenNodePanel={{@onOpenNodePanel}}
        @onAddStickyNote={{@onAddStickyNote}}
        @onRegister={{this.registerContextMenu}}
      />
    </div>
  </template>
}
