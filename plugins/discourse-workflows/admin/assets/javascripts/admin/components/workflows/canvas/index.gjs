import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BuildWithAiModal from "../build-with-ai-modal";
import {
  buildCanvasClipboardPayload,
  isSerializedCanvasClipboardPayload,
  parseCanvasClipboardText,
  payloadForCanvasClipboardPaste,
  positionCanvasClipboardPayload,
  serializeCanvasClipboardPayload,
} from "./canvas-clipboard";
import CanvasContextMenu from "./canvas-context-menu";
import { runExecuteStep } from "./canvas-execute-step";
import { exportWorkflowToFile, parseWorkflowImport } from "./canvas-file-io";
import { setupCanvasKeyboard } from "./canvas-keyboard";
import { runManualTrigger } from "./canvas-manual-trigger";
import {
  buildStickyNoteTranslateHandler,
  computeStickyNoteRects,
} from "./canvas-sticky-notes";
import ConnectionEntry from "./connection-entry";
import Controls from "./controls";
import LoopBackConnection from "./loop-back-connection";
import { createReteEditor } from "./rete-editor";
import StickyNoteComponent from "./sticky-note";
import WorkflowNode from "./workflow-node";

export default class WorkflowCanvas extends Component {
  @service keyboardShortcuts;
  @service dialog;
  @service menu;
  @service router;
  @service workflowsNodeTypes;
  @service toasts;
  @service siteSettings;

  @tracked isLoading = true;
  @tracked rete = null;
  @tracked areaTransform = { x: 0, y: 0, k: 1 };
  @tracked workflowPublishedOverride = null;
  @tracked hasUnpublishedChangesOverride = null;
  @tracked selectionVersion = 0;
  @tracked aiPanelOpen = false;
  clipboardPayload = null;
  serializedClipboardPayload = null;
  clipboardWritePending = false;
  pasteOffset = 0;
  isFirstSync = true;
  lastAutoArrangeRequest = 0;
  didHydrateInitialAutoLayout = false;
  #hasSetupStarted = false;
  #pendingSync = false;
  #syncTask = null;
  #pendingInsertHighlights = new Set();
  #syncedNodeClientIds = null;
  #outsideClickAbort = null;
  #ZOOM_STEP = 0.1;
  #ZOOM_MIN = 0.25;
  #ZOOM_MAX = 4;

  willDestroy() {
    super.willDestroy();
    this.rete?.destroy();
    this.keyboard?.teardown();
    this.#outsideClickAbort?.abort();
  }

  get workflowPublished() {
    return (
      this.workflowPublishedOverride ?? Boolean(this.args.workflowPublished)
    );
  }

  get hasUnpublishedChanges() {
    return (
      this.hasUnpublishedChangesOverride ??
      Boolean(this.args.hasUnpublishedChanges)
    );
  }

  get publishDisabled() {
    return this.workflowPublished && !this.hasUnpublishedChanges;
  }

  get hasNodes() {
    return (this.args.nodes || []).length > 0;
  }

  get showPublishButton() {
    return this.hasNodes && !this.publishDisabled;
  }

  get showToolbarPublishButton() {
    return this.showPublishButton && !this.showUnpublishedChangesMessage;
  }

  get showUnpublishedChangesMessage() {
    return this.showPublishButton;
  }

  get showDiscardChangesButton() {
    return this.workflowPublished && this.hasUnpublishedChanges;
  }

  get aiAuthoringAvailable() {
    return (
      this.siteSettings.discourse_workflows_ai_authoring_enabled &&
      this.args.workflowId
    );
  }

  @action
  openAiPanel() {
    this.aiPanelOpen = true;
  }

  @action
  closeAiPanel() {
    this.aiPanelOpen = false;
  }

  @action
  isStickyNoteSelected(clientId) {
    this.selectionVersion;
    return this.rete.isStickyNoteSelected(clientId);
  }

  @action
  async publishWorkflow() {
    if (!this.hasNodes) {
      return;
    }

    this.workflowPublishedOverride = true;
    this.hasUnpublishedChangesOverride = false;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              published: true,
            },
          },
        }
      );
      if (this.args.workflow) {
        this.args.workflow.activeVersionId = this.args.workflow.versionId;
        this.args.workflow.hasUnpublishedChanges = false;
      }
      this.workflowPublishedOverride = null;
      this.hasUnpublishedChangesOverride = null;
    } catch {
      this.workflowPublishedOverride = this.args.workflowPublished;
      this.hasUnpublishedChangesOverride = this.args.hasUnpublishedChanges;
    }
  }

  @action
  async discardWorkflow() {
    const confirmed = await this.dialog.confirm({
      message: i18n("discourse_workflows.discard_changes_confirmation"),
      confirmButtonLabel: "discourse_workflows.discard_changes",
      cancelButtonLabel: "discourse_workflows.keep_editing",
    });

    if (!confirmed) {
      return;
    }

    this.hasUnpublishedChangesOverride = false;

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/discard-draft.json`,
        {
          type: "POST",
        }
      );

      this.args.onDiscardWorkflow?.(response.workflow);
      this.hasUnpublishedChangesOverride = null;
    } catch (e) {
      this.hasUnpublishedChangesOverride = this.args.hasUnpublishedChanges;
      popupAjaxError(e);
    }
  }

  @action
  async unpublishWorkflow(closeMenu) {
    if (typeof closeMenu === "function") {
      closeMenu();
    }
    this.workflowPublishedOverride = false;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}.json`,
        {
          type: "PUT",
          data: {
            workflow: {
              published: false,
            },
          },
        }
      );
      if (this.args.workflow) {
        this.args.workflow.activeVersionId = null;
        this.args.workflow.hasUnpublishedChanges = true;
      }
      this.workflowPublishedOverride = null;
    } catch {
      this.workflowPublishedOverride = this.args.workflowPublished;
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
      onCut: () => this.cutSelected(),
      onCopy: () => this.copySelected(),
      onPaste: (event) => this.handlePasteEvent(event),
      onDelete: () => this.deleteSelected(),
      onEscape: () => {
        this.contextMenuApi?.close();
        this.rete.selector.unselectAll();
        this.selectionVersion++;
      },
      onZoomIn: () => this.zoomIn(),
      onZoomOut: () => this.zoomOut(),
      onFitToView: () => this.fitToView(),
      onAutoLayout: () => this.autoLayout(),
    };
  }

  async #handleManualTrigger(clientId) {
    try {
      await runManualTrigger({
        node: this.#nodes().find((n) => n.clientId === clientId),
        clientId,
        workflowId: this.args.workflowId,
        toasts: this.toasts,
        router: this.router,
        session: this.args.session,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  async #handleExecuteStep(clientId) {
    try {
      await runExecuteStep({
        clientId,
        workflowId: this.args.workflowId,
        toasts: this.toasts,
        router: this.router,
      });
    } catch (e) {
      popupAjaxError(e);
    }
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
      onSelectionDragFinished: (selectionRect) =>
        this.#selectStickyNotesInRect(selectionRect),
      onNodeDragEnd: () => this.args.onNodeDragEnd?.(),
      onConnectionCreated: (...a) => this.args.onCreateConnection?.(...a),
      onNodeDelete: (clientId) => this.args.onRemoveNodes?.([clientId]),
      onManualTrigger: (clientId) => this.#handleManualTrigger(clientId),
      onExecuteStep: (clientId) => this.#handleExecuteStep(clientId),
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

  async #selectStickyNotesInRect(selectionRect) {
    for (const noteRect of this.#stickyNoteRects()) {
      if (this.#rectsIntersect(noteRect, selectionRect)) {
        await this.rete.selectStickyNote(
          noteRect.clientId,
          {
            onStickyNoteTranslate: buildStickyNoteTranslateHandler(
              () => this.args.stickyNotes,
              this.args.onStickyNoteMove
            ),
            onStickyNoteUnselect: () => {
              this.selectionVersion++;
            },
          },
          { accumulate: true }
        );
      }
    }

    this.selectionVersion++;
  }

  #rectsIntersect(rect, selectionRect) {
    return !(
      rect.x + rect.width < selectionRect.left ||
      rect.x > selectionRect.right ||
      rect.y + rect.height < selectionRect.top ||
      rect.y > selectionRect.bottom
    );
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

  // Rete re-renders node views on selection and config changes, remounting
  // their components, so the insert pulse is keyed off client ids appearing
  // in the synced data rather than DOM insertion.
  #trackInsertedNodes(nodes) {
    const clientIds = new Set(nodes.map((node) => node.clientId));

    if (this.#syncedNodeClientIds) {
      for (const clientId of clientIds) {
        if (!this.#syncedNodeClientIds.has(clientId)) {
          this.#pendingInsertHighlights.add(clientId);
        }
      }
    }

    this.#syncedNodeClientIds = clientIds;
  }

  @action
  consumeInsertHighlight(clientId) {
    return this.#pendingInsertHighlights.delete(clientId);
  }

  async #performSync() {
    const snapshot = {
      nodes: this.#nodes(),
      connections: this.#connections(),
      stickyNoteRects: this.#stickyNoteRects(),
      autoArrangeRequest: this.args.autoArrangeRequest || 0,
    };
    const prevNodeCount = this.rete.nodeCount;

    this.#trackInsertedNodes(snapshot.nodes);
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
    } catch {
      this.#pendingSync = false;
      this.toasts.error({
        data: { message: i18n("discourse_workflows.canvas.sync_error") },
      });
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
    const nodeTypes = await this.workflowsNodeTypes.load();

    this.rete = await createReteEditor(this.containerElement, {
      nodeTypes,
      callbacks: this.#reteCallbacks(),
    });

    this.keyboard = setupCanvasKeyboard(
      this.keyboardShortcuts,
      this.#keyboardActions(),
      element
    );

    this.args.onAreaReady?.(this.rete.area);
    this.#forwardTrappedPointerdowns();

    await this.#queueSync();
    this.isLoading = false;
    element.focus();
  }

  // Left clicks are trapped on the canvas and never reach the document
  // so we re-emit one to clean up any open menus outside of the canvas
  #forwardTrappedPointerdowns() {
    this.#outsideClickAbort = new AbortController();

    this.containerElement.addEventListener(
      "pointerdown",
      (event) => {
        if (event.button === 0) {
          document.body.dispatchEvent(
            new PointerEvent("pointerdown", { bubbles: true })
          );
        }
      },
      { capture: true, signal: this.#outsideClickAbort.signal }
    );
  }

  @action
  async syncToRete() {
    await this.#queueSync();
  }

  get nodeEntries() {
    return this.rete.renderer.nodeEntryList;
  }

  get connectionEntries() {
    return this.rete.renderer.connectionEntryList;
  }

  get handleEntries() {
    return [
      ...this.rete.renderer.outputHandleEntryList,
      ...this.rete.renderer.inputHandleEntryList,
    ].map((entry) => ({
      ...entry,
      svgStyle: trustHTML(
        `overflow:visible;position:absolute;pointer-events:none;z-index:2;left:${entry.svgLeft}px;top:${entry.svgTop}px;width:50px;height:20px`
      ),
    }));
  }

  get areaContentElement() {
    return this.rete.areaContentElement;
  }

  @action
  handleConnectionToolbarAdd(connectionInfo) {
    this.args.onOpenNodePanel?.({
      connectionSource: connectionInfo.sourceClientId,
      connectionSourceOutput: connectionInfo.sourceOutput,
      connectionSourceOutputIndex: connectionInfo.sourceOutputIndex,
      connectionTarget: connectionInfo.targetClientId,
      connectionTargetInput: connectionInfo.targetInput,
      connectionTargetInputIndex: connectionInfo.targetInputIndex,
    });
  }

  @action
  handleConnectionToolbarDelete(connectionInfo) {
    this.args.onConnectionDelete?.(
      connectionInfo.sourceClientId,
      connectionInfo.sourceOutput,
      connectionInfo.targetClientId,
      connectionInfo.targetInput,
      connectionInfo.sourceOutputIndex,
      connectionInfo.targetInputIndex
    );
  }

  @action
  handleLoopBackAdd(loopNodeClientId) {
    this.args.onOpenNodePanel?.({ loopNodeClientId });
  }

  @action
  handleHandleAdd(nodeClientId, outputKey, inputKey, e) {
    e.stopPropagation();
    this.args.onOpenNodePanel?.(
      outputKey !== null
        ? { sourceClientId: nodeClientId, sourceOutput: outputKey }
        : { targetClientId: nodeClientId, targetInput: inputKey || "main" }
    );
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
    this.contextMenuApi?.close();
    callback?.(this.rete.viewportCenter());
  }

  @action
  openNodePanelAtCenter() {
    this.#invokeAtViewportCenter(this.args.onOpenNodePanel);
  }

  @action
  browseTemplates() {
    this.args.onBrowseTemplates?.();
  }

  @action
  async selectStickyNote(clientId) {
    await this.rete.selectStickyNote(clientId, {
      onStickyNoteTranslate: buildStickyNoteTranslateHandler(
        () => this.args.stickyNotes,
        this.args.onStickyNoteMove
      ),
      onStickyNoteUnselect: () => {
        this.selectionVersion++;
      },
    });
    this.selectionVersion++;
  }

  #selectedIds(selection = null) {
    if (!selection) {
      return this.rete.getSelectedIds();
    }

    return {
      nodeIds: new Set(selection.nodeIds || []),
      stickyNoteIds: new Set(selection.stickyNoteIds || []),
    };
  }

  #selectedClipboardPayload(selection = null) {
    return buildCanvasClipboardPayload(
      {
        nodes: this.args.nodes || [],
        connections: this.args.connections || [],
        stickyNotes: this.args.stickyNotes || [],
      },
      this.#selectedIds(selection)
    );
  }

  #storeClipboardPayload(payload) {
    this.clipboardPayload = payload;
    this.serializedClipboardPayload = serializeCanvasClipboardPayload(payload);
    this.pasteOffset = 0;
  }

  async #writeClipboardPayload() {
    this.clipboardWritePending = true;

    try {
      await clipboardCopy(this.serializedClipboardPayload);
    } catch {
      this.toasts.warning({
        data: {
          message: i18n("discourse_workflows.canvas.clipboard_unavailable"),
        },
      });
    } finally {
      this.clipboardWritePending = false;
    }
  }

  #showNothingToPaste() {
    this.toasts.info({
      data: { message: i18n("discourse_workflows.canvas.nothing_to_paste") },
    });
  }

  #copySelectedPayload(selection = null) {
    const payload = this.#selectedClipboardPayload(selection);

    if (!payload) {
      return null;
    }

    this.#storeClipboardPayload(payload);
    void this.#writeClipboardPayload();

    return payload;
  }

  @action
  copySelected(selection = null) {
    this.contextMenuApi?.close();
    this.#copySelectedPayload(selection);
  }

  @action
  cutSelected(selection = null) {
    this.contextMenuApi?.close();
    const selectedIds = this.#selectedIds(selection);

    if (!this.#copySelectedPayload(selectedIds)) {
      return;
    }

    this.args.onCutSelected?.({
      nodeIds: [...selectedIds.nodeIds],
      stickyNoteIds: [...selectedIds.stickyNoteIds],
    });
    this.rete.selector.unselectAll();
    this.selectionVersion++;
  }

  #positionedPayload(payload, { target = null, useSourceOffset = false } = {}) {
    const sourceOffset = useSourceOffset ? (this.pasteOffset += 20) : 0;

    return positionCanvasClipboardPayload(payload, { target, sourceOffset });
  }

  #pastePayload(payload, options = {}) {
    if (!this.rete) {
      return;
    }

    this.args.onPasteEntities?.(this.#positionedPayload(payload, options));
  }

  async #readClipboardPayload() {
    if (!navigator.clipboard?.readText) {
      return { payload: null, didRead: false };
    }

    try {
      const text = await navigator.clipboard.readText();
      return {
        payload: parseCanvasClipboardText(text),
        didRead: true,
        isLocal: isSerializedCanvasClipboardPayload(
          text,
          this.serializedClipboardPayload
        ),
      };
    } catch {
      return { payload: null, didRead: false };
    }
  }

  @action
  handlePasteEvent(event) {
    if (!this.rete) {
      return;
    }

    const text = event.clipboardData?.getData("text/plain");
    const payload = this.clipboardWritePending
      ? null
      : parseCanvasClipboardText(text);
    const useLocalPayload = !payload && this.clipboardPayload;
    const pastePayload = payloadForCanvasClipboardPaste(
      payload,
      useLocalPayload ? this.clipboardPayload : null
    );

    if (!pastePayload) {
      return;
    }

    event.preventDefault();
    const isLocal =
      useLocalPayload ||
      isSerializedCanvasClipboardPayload(text, this.serializedClipboardPayload);

    this.#pastePayload(pastePayload, {
      target: isLocal ? null : this.rete.viewportCenter(),
      useSourceOffset: isLocal,
    });
  }

  @action
  async pasteFromClipboard(target = null) {
    this.contextMenuApi?.close();
    const result = await this.#readClipboardPayload();
    const systemPayload = this.clipboardWritePending ? null : result.payload;
    const useLocalPayload = !systemPayload && this.clipboardPayload;
    const payload = payloadForCanvasClipboardPaste(
      systemPayload,
      useLocalPayload ? this.clipboardPayload : null
    );

    if (!payload) {
      this.#showNothingToPaste();
      return;
    }

    this.#pastePayload(payload, {
      target,
      useSourceOffset: !target && (result.isLocal || useLocalPayload),
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
    const { stickyNoteIds } = this.rete.getSelectedIds();

    for (const stickyNoteId of stickyNoteIds) {
      if (stickyNoteId === draggedClientId) {
        continue;
      }

      const note = (this.args.stickyNotes || []).find(
        (stickyNote) => stickyNote.clientId === stickyNoteId
      );
      if (note) {
        this.args.onStickyNoteMove?.(stickyNoteId, {
          x: note.position.x + dx,
          y: note.position.y + dy,
        });
      }
    }

    await this.rete.translateSelectedEntities(
      draggedClientId,
      "sticky-note",
      dx,
      dy,
      { labels: ["node"] }
    );
  }

  @action
  deleteSelected(selection = null) {
    const { nodeIds, stickyNoteIds } = this.#selectedIds(selection);
    if (nodeIds.size > 0 || stickyNoteIds.size > 0) {
      this.args.onRemoveSelected?.({
        nodeIds: [...nodeIds],
        stickyNoteIds: [...stickyNoteIds],
      });
      this.rete.selector.unselectAll();
      this.selectionVersion++;
    }
  }

  async #applyZoom(delta) {
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
    await this.rete.fitToView(this.#stickyNoteRects());
  }

  @action
  async autoLayout() {
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
      this.args.stickyNotes,
      this.args.workflow
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
        result.stickyNotes,
        result.staticData
      );
    } catch {
      this.#showImportError();
    }
  }

  <template>
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

      <div
        class="workflows-canvas__rete-container"
        {{didInsert this.registerContainer}}
      ></div>

      {{#if this.rete}}
        {{#if this.showEmptyState}}
          <div class="workflows-canvas__empty-state">
            <div class="workflows-canvas__empty-state-options">
              <button
                type="button"
                class="workflows-canvas__empty-state-trigger"
                {{on "click" this.openNodePanelAtCenter}}
              >
                <span class="workflows-canvas__empty-state-tile">
                  {{dIcon "plus"}}
                </span>
                <span class="workflows-canvas__empty-state-label">
                  {{i18n "discourse_workflows.add_node.first_step"}}
                </span>
              </button>

              <button
                type="button"
                class="workflows-canvas__empty-state-trigger"
                {{on "click" this.browseTemplates}}
              >
                <span class="workflows-canvas__empty-state-tile">
                  {{dIcon "layer-group"}}
                </span>
                <span class="workflows-canvas__empty-state-label">
                  {{i18n "discourse_workflows.add_node.browse_templates"}}
                </span>
              </button>
            </div>
          </div>
        {{/if}}

        {{#each this.nodeEntries as |entry|}}
          {{#in-element entry.element insertBefore=null}}
            <WorkflowNode
              @node={{entry.node}}
              @consumeInsertHighlight={{this.consumeInsertHighlight}}
              @onDelete={{this.rete.renderer.onNodeDelete}}
              @onManualTrigger={{this.rete.renderer.onManualTrigger}}
              @onExecuteStep={{this.rete.renderer.onExecuteStep}}
              @onSocketRendered={{this.rete.renderer.onSocketRendered}}
              @onEditNode={{@onEditNode}}
              @workflowPublished={{this.workflowPublished}}
              @session={{@session}}
            />
          {{/in-element}}
        {{/each}}

        {{#each this.connectionEntries as |entry|}}
          {{#in-element entry.element insertBefore=null}}
            {{#if entry.isLoopBack}}
              <LoopBackConnection
                @entry={{entry}}
                @onAdd={{this.handleLoopBackAdd}}
              />
            {{else}}
              <ConnectionEntry
                @entry={{entry}}
                @onAdd={{this.handleConnectionToolbarAdd}}
                @onDelete={{this.handleConnectionToolbarDelete}}
              />
            {{/if}}
          {{/in-element}}
        {{/each}}

        {{#each this.handleEntries as |entry|}}
          {{#in-element entry.areaElement insertBefore=null}}

            <svg class="workflow-handle" style={{entry.svgStyle}}>
              <path
                fill="none"
                stroke="var(--primary-low-mid)"
                stroke-width="1.5"
                d={{entry.pathD}}
              />
              <foreignObject
                class="workflow-handle__button-fo"
                width="14"
                height="14"
                x={{entry.buttonX}}
                y={{entry.buttonY}}
              >
                <button
                  type="button"
                  class="workflow-handle__add-btn"
                  {{on
                    "click"
                    (fn
                      this.handleHandleAdd
                      entry.nodeClientId
                      entry.outputKey
                      entry.inputKey
                    )
                  }}
                >
                  {{dIcon "plus"}}
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

        {{#if @onOpenNodePanel}}
          <div class="workflows-canvas__top-bar">
            {{#if this.showUnpublishedChangesMessage}}
              <div class="workflows-canvas__publish-status">
                <span
                  class="workflows-canvas__publish-status-body"
                  role="status"
                >
                  <span class="workflows-canvas__publish-status-icon">
                    {{dIcon "triangle-exclamation"}}
                  </span>
                  <span class="workflows-canvas__publish-status-text">
                    <span class="workflows-canvas__publish-status-title">
                      {{i18n "discourse_workflows.unpublished_changes_message"}}
                    </span>
                    <span class="workflows-canvas__publish-status-detail">
                      {{i18n
                        "discourse_workflows.unpublished_changes_message_detail"
                      }}
                    </span>
                  </span>
                </span>

                <span class="workflows-canvas__publish-status-actions">
                  <DButton
                    @action={{this.publishWorkflow}}
                    @translatedLabel={{i18n "discourse_workflows.publish"}}
                    class="btn-primary btn-small workflows-canvas__publish-status-btn"
                  />

                  {{#if this.showDiscardChangesButton}}
                    <DButton
                      @action={{this.discardWorkflow}}
                      @translatedLabel={{i18n
                        "discourse_workflows.discard_changes"
                      }}
                      class="btn-default btn-small workflows-canvas__publish-status-btn"
                    />
                  {{/if}}
                </span>
              </div>
            {{/if}}

            <div class="workflows-canvas__toolbar-top-right">
              {{#if this.showToolbarPublishButton}}
                <DButton
                  @action={{this.publishWorkflow}}
                  @translatedLabel={{i18n "discourse_workflows.publish"}}
                  class="btn-primary workflows-canvas__publish-btn"
                />
              {{/if}}

              {{#if this.aiAuthoringAvailable}}
                <DButton
                  @action={{this.openAiPanel}}
                  @icon="discourse-sparkles"
                  @translatedLabel={{i18n "discourse_workflows.ai.button"}}
                  class="btn-default workflows-canvas__ai-btn"
                />
              {{/if}}

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
                  <DDropdownMenu as |dropdown|>
                    {{#if this.workflowPublished}}
                      <dropdown.item>
                        <DButton
                          @action={{fn this.unpublishWorkflow args.close}}
                          @translatedLabel={{i18n
                            "discourse_workflows.unpublish"
                          }}
                          class="btn-transparent"
                        />
                      </dropdown.item>
                    {{/if}}
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
                  </DDropdownMenu>
                </:content>
              </DMenu>
            </div>
          </div>
        {{/if}}

        {{#if this.aiAuthoringAvailable}}
          <BuildWithAiModal
            @open={{this.aiPanelOpen}}
            @workflowId={{@workflowId}}
            @onApply={{@onWorkflowUpdated}}
            @onClose={{this.closeAiPanel}}
          />
        {{/if}}

        <CanvasContextMenu
          @canvasElement={{this.canvasElement}}
          @containerElement={{this.containerElement}}
          @rete={{this.rete}}
          @onEditNode={{@onEditNode}}
          @onDeleteSelected={{this.deleteSelected}}
          @onCut={{this.cutSelected}}
          @onCopy={{this.copySelected}}
          @onPaste={{this.pasteFromClipboard}}
          @onOpenNodePanel={{@onOpenNodePanel}}
          @onAddStickyNote={{@onAddStickyNote}}
          @onRegister={{this.registerContextMenu}}
        />
      {{/if}}
    </div>
  </template>
}
