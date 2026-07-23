import loadRete from "discourse/lib/load-rete";
import {
  buildConnectedOutputsIndex,
  buildOutgoingIndex,
  buildWorkflowGraphIndex,
  graphConnectionKey,
  LOOP_OUTPUT,
  nextAvailableTargetInputIndex,
  normalizeSourceOutput,
  normalizeSourceOutputIndex,
  normalizeTargetInput,
  normalizeTargetInputIndex,
  portIndexFromKey,
} from "../../../lib/workflows/graph-constants";
import {
  nodeTypeInputAcceptsMultipleConnections,
  nodeTypeInputs,
  nodeTypeInputUsesConnectionIndexes,
  nodeTypeOutputKeys,
} from "../../../lib/workflows/node-types";
import {
  NODE_WIDTH,
  nodeHeight,
  nodeLabel,
  nodeWidth,
} from "../../../lib/workflows/node-utils";
import { createCustomRenderer } from "./custom-renderer";

export const DRAG_LENIENCE_PX = 4;

export class ReteEditorBridge {
  static async create(container, { callbacks, nodeTypes = [] }) {
    const {
      ClassicPreset,
      NodeEditor,
      Scope,
      AreaPlugin,
      AreaExtensions,
      ConnectionPlugin,
      ConnectionPresets,
      Zoom,
      dagre,
      classicConnectionPath,
      getElementCenter,
    } = await loadRete();

    const socket = new ClassicPreset.Socket("workflow");
    const nodeTypesByIdentifier = new Map(
      (nodeTypes || []).flatMap((nodeType) => [
        [nodeType.name, nodeType],
        [nodeType.identifier, nodeType],
      ])
    );
    const getNodeWidth = (data) =>
      nodeWidth(data, {
        nodeType: nodeTypesByIdentifier.get(data.type),
      });
    const getNodeHeight = (data) =>
      nodeHeight(data, nodeTypesByIdentifier.get(data.type));
    const getNodeLabel = (data) =>
      nodeLabel(data, nodeTypesByIdentifier.get(data.type));
    const inputKeysFor = (data) =>
      data.type?.startsWith("trigger:")
        ? []
        : nodeTypeInputs(
            nodeTypesByIdentifier.get(data.type) || data.type,
            data
          ).map((input) => input.key || "main");

    class WorkflowNode extends ClassicPreset.Node {
      constructor(data) {
        super(getNodeLabel(data) || data.name || "Node");
        this.id = data.clientId;
        this.workflowData = data;
        this.width = getNodeWidth(data);
        this.height = getNodeHeight(data);

        if (!data.type?.startsWith("trigger:")) {
          for (const input of nodeTypeInputs(
            nodeTypesByIdentifier.get(data.type) || data.type,
            data
          )) {
            const key = input.key || "main";
            this.addInput(
              key,
              new ClassicPreset.Input(
                socket,
                key === "main" ? "" : key,
                nodeTypeInputAcceptsMultipleConnections(
                  nodeTypesByIdentifier.get(data.type) || data.type,
                  key,
                  data
                )
              )
            );
          }
        }

        for (const key of nodeTypeOutputKeys(
          nodeTypesByIdentifier.get(data.type) || data.type,
          data
        )) {
          this.addOutput(key, new ClassicPreset.Output(socket, key, true));
        }
      }
    }

    const CustomRenderer = createCustomRenderer(
      Scope,
      getElementCenter,
      classicConnectionPath
    );

    const editor = new NodeEditor();
    const area = new AreaPlugin(container);
    const connectionPlugin = new ConnectionPlugin();
    const renderer = new CustomRenderer();
    renderer.onManualTrigger = callbacks.onManualTrigger;
    renderer.onExecuteStep = callbacks.onExecuteStep;

    connectionPlugin.addPreset(ConnectionPresets.classic.setup());

    editor.use(area);
    area.use(connectionPlugin);
    area.use(renderer);
    area.area.setZoomHandler(new Zoom(0.05));

    AreaExtensions.simpleNodesOrder(area);

    class ToggleSelector extends AreaExtensions.Selector {
      async add(entity, accumulate) {
        const entityKey = `${entity.label}_${entity.id}`;

        if (this.entities.has(entityKey)) {
          if (accumulate) {
            await this.remove(entity);
          }
          return;
        }

        await super.add(entity, accumulate);
      }
    }

    const selector = new ToggleSelector();
    let shiftPressed = false;
    const shiftAbort = new AbortController();
    const opts = { signal: shiftAbort.signal };
    document.addEventListener(
      "keydown",
      (e) => {
        if (e.key === "Shift") {
          shiftPressed = true;
        }
      },
      opts
    );
    document.addEventListener(
      "keyup",
      (e) => {
        if (e.key === "Shift") {
          shiftPressed = false;
        }
      },
      opts
    );
    document.addEventListener(
      "visibilitychange",
      () => {
        shiftPressed = false;
      },
      opts
    );
    const accumulating = { active: () => shiftPressed };

    area.addPipe((context) => {
      if (context.type === "pointerdown") {
        const event = context.data.event;
        if (event.button !== 0) {
          return;
        }

        const target = event.target;
        if (target?.closest?.(".workflow-sticky-note")) {
          return;
        }
      }
      return context;
    });

    const selectableNodes = AreaExtensions.selectableNodes(area, selector, {
      accumulating,
    });

    const bridge = new ReteEditorBridge({
      editor,
      area,
      renderer,
      selector,
      selectableNodes,
      connectionPlugin,
      dagre,
      container,
      callbacks,
      WorkflowNode,
      ClassicPreset,
      AreaExtensions,
      accumulating,
      shiftAbort,
      getNodeWidth,
      getNodeHeight,
      getNodeLabel,
      inputKeysFor,
      nodeTypesByIdentifier,
    });

    renderer.onNodeDelete = (clientId) => {
      if (!bridge.isSyncing) {
        callbacks.onNodeDelete?.(clientId);
      }
    };

    bridge.setupPipes();
    return bridge;
  }

  constructor({
    editor,
    area,
    renderer,
    selector,
    selectableNodes,
    connectionPlugin,
    dagre,
    container,
    callbacks,
    WorkflowNode,
    ClassicPreset,
    AreaExtensions,
    accumulating,
    shiftAbort,
    getNodeWidth,
    getNodeHeight,
    getNodeLabel,
    inputKeysFor,
    nodeTypesByIdentifier,
  }) {
    this.editor = editor;
    this.area = area;
    this.renderer = renderer;
    this.selector = selector;
    this.selectableNodes = selectableNodes;
    this.connectionPlugin = connectionPlugin;
    this.dagre = dagre;
    this.container = container;
    this.callbacks = callbacks;
    this.accumulating = accumulating;
    this.shiftAbort = shiftAbort;
    this.WorkflowNode = WorkflowNode;
    this.ClassicPreset = ClassicPreset;
    this.AreaExtensions = AreaExtensions;
    this.getNodeWidth = getNodeWidth;
    this.getNodeHeight = getNodeHeight;
    this.getNodeLabel = getNodeLabel;
    this.inputKeysFor = inputKeysFor;
    this.nodeTypesByIdentifier = nodeTypesByIdentifier;
    this.isSyncing = false;
    this.isAutoArranging = false;
    this.wasDragging = false;
    this.selectionDrag = null;
    this.selectionBoxElement = null;
    this.lastPickedId = null;
    this.lastPickedTime = 0;
    this.nodeDragOrigin = null;
  }

  setupPipes() {
    this.area.addPipe(async (context) => {
      if (this.isSyncing || this.isAutoArranging) {
        return context;
      }

      switch (context.type) {
        case "translate":
          if (this.selectionDrag) {
            return;
          }
          break;

        case "nodetranslate": {
          const origin = this.nodeDragOrigin;
          if (origin && origin.id === context.data.id) {
            const { position } = context.data;
            const { k } = this.area.area.transform;
            const distance = Math.hypot(
              (position.x - origin.x) * k,
              (position.y - origin.y) * k
            );
            if (distance < DRAG_LENIENCE_PX) {
              return;
            }
            this.nodeDragOrigin = null;
          }
          break;
        }

        case "nodetranslated":
          this.callbacks.onNodeDragged?.(
            context.data.id,
            context.data.position
          );
          if (!this.wasDragging) {
            this.container.classList.add("is-dragging");
          }
          this.wasDragging = true;
        // falls through to emit transform
        case "translated":
        case "zoomed": {
          const { x, y, k } = this.area.area.transform;
          this.callbacks.onTransformChanged?.({ x, y, k });
          break;
        }

        case "nodepicked": {
          const pickedId = context.data.id;
          const view = this.area.nodeViews.get(pickedId);
          this.nodeDragOrigin = view
            ? { id: pickedId, x: view.position.x, y: view.position.y }
            : null;
          this.callbacks.onNodePicked?.();
          const now = Date.now();
          if (
            pickedId === this.lastPickedId &&
            now - this.lastPickedTime < 500
          ) {
            this.callbacks.onNodeDoubleClick?.(pickedId);
            this.lastPickedId = null;
          } else {
            this.lastPickedId = pickedId;
          }
          this.lastPickedTime = now;
          break;
        }

        case "pointermove":
          if (this.selectionDrag) {
            this.updateSelectionDrag(context.data);
            return;
          }
          break;

        case "pointerup":
          this.nodeDragOrigin = null;

          if (this.selectionDrag) {
            await this.finishSelectionDrag(context.data);
            return;
          }

          if (this.wasDragging) {
            this.wasDragging = false;
            this.container.classList.remove("is-dragging");
            this.callbacks.onNodeDragEnd?.();
          }
          break;

        case "pointerdown": {
          const target = context.data.event.target;
          if (!target?.closest?.(".workflow-rete-node")) {
            this.callbacks.onCanvasPointerDown?.(context.data.event);
            if (this.canStartSelectionDrag(context.data.event)) {
              this.startSelectionDrag(context.data);
              return;
            }
          }
          break;
        }
      }

      return context;
    });

    this.connectionPlugin.addPipe((context) => {
      if (context.type === "connectionpick") {
        const pickedSocket = context.data.socket;
        this.container.classList.add("is-connection-dragging");
        this.updateInvalidConnectionTargets(pickedSocket?.side);
        this.markConnectionSourceNode(pickedSocket?.nodeId);
      } else if (context.type === "connectiondrop") {
        this.container.classList.remove("is-connection-dragging");
        this.clearInvalidConnectionTargets();
        this.clearConnectionSourceNode();
      }
      return context;
    });

    this.editor.addPipe((context) => {
      if (this.isSyncing) {
        return context;
      }

      if (
        context.type === "connectioncreated" ||
        context.type === "connectionremoved"
      ) {
        if (context.type === "connectioncreated") {
          this.annotateConnectionIndexes(context.data);
        }

        this.updateRendererGraphIndex();
        this.renderer.scheduleConnectionUpdate();

        if (context.type === "connectioncreated") {
          const conn = context.data;
          this.callbacks.onConnectionCreated?.(
            conn.source,
            conn.sourceOutput,
            conn.target,
            conn.targetInput,
            conn.sourceOutputIndex,
            conn.targetInputIndex
          );
        }
      }

      return context;
    });
  }

  clearInvalidConnectionTargets() {
    for (const socket of this.container.querySelectorAll(
      ".workflow-rete-node__socket.is-invalid-connection-target"
    )) {
      socket.classList.remove("is-invalid-connection-target");
    }
  }

  updateInvalidConnectionTargets(pickedSide) {
    this.clearInvalidConnectionTargets();

    if (!pickedSide) {
      return;
    }

    for (const socket of this.container.querySelectorAll(
      ".workflow-rete-node__socket"
    )) {
      const socketSide = socket.classList.contains("--input")
        ? "input"
        : "output";
      const isLoopSocket = socket.classList.contains("--loop");

      socket.classList.toggle(
        "is-invalid-connection-target",
        isLoopSocket || socketSide === pickedSide
      );
    }
  }

  markConnectionSourceNode(nodeId) {
    this.clearConnectionSourceNode();
    if (nodeId) {
      this.area.nodeViews
        .get(nodeId)
        ?.element.classList.add("is-connection-source");
    }
  }

  clearConnectionSourceNode() {
    for (const element of this.container.querySelectorAll(
      ".workflow-rete-node-view.is-connection-source"
    )) {
      element.classList.remove("is-connection-source");
    }
  }

  pointerPosition(data) {
    const event = data.event;

    if (Number.isFinite(event?.clientX) && Number.isFinite(event?.clientY)) {
      const rect = this.container.getBoundingClientRect();
      return {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top,
      };
    }

    return {
      x: data.position.x * this.transform.k + this.transform.x,
      y: data.position.y * this.transform.k + this.transform.y,
    };
  }

  canStartSelectionDrag(event) {
    return (
      event?.button === 0 &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.shiftKey &&
      !event.target?.closest?.(
        "button,a,input,textarea,select,.workflow-sticky-note,.workflows-canvas__controls,.workflows-canvas__top-bar"
      )
    );
  }

  startSelectionDrag(data) {
    const start = this.pointerPosition(data);
    this.selectionBoxElement?.remove();
    this.selectionDrag = { start, current: start };
    this.container.classList.add("is-selecting");
    this.selectionBoxElement = document.createElement("div");
    this.selectionBoxElement.className = "workflows-canvas__selection-box";
    this.container.appendChild(this.selectionBoxElement);
    this.updateSelectionBox();
  }

  updateSelectionDrag(data) {
    this.selectionDrag.current = this.pointerPosition(data);
    this.updateSelectionBox();
  }

  updateSelectionBox() {
    const { start, current } = this.selectionDrag;
    const left = Math.min(start.x, current.x);
    const top = Math.min(start.y, current.y);
    const width = Math.abs(current.x - start.x);
    const height = Math.abs(current.y - start.y);

    Object.assign(this.selectionBoxElement.style, {
      left: `${left}px`,
      top: `${top}px`,
      width: `${width}px`,
      height: `${height}px`,
    });
  }

  async finishSelectionDrag(data) {
    this.updateSelectionDrag(data);
    const { start, current } = this.selectionDrag;
    const distance = Math.hypot(current.x - start.x, current.y - start.y);

    this.selectionBoxElement?.remove();
    this.selectionBoxElement = null;
    this.selectionDrag = null;
    this.container.classList.remove("is-selecting");

    await this.selector.unselectAll();

    if (distance < DRAG_LENIENCE_PX) {
      return;
    }

    const startCanvas = this.containerToCanvas(start.x, start.y);
    const currentCanvas = this.containerToCanvas(current.x, current.y);
    const selectionRect = {
      left: Math.min(startCanvas.canvasX, currentCanvas.canvasX),
      right: Math.max(startCanvas.canvasX, currentCanvas.canvasX),
      top: Math.min(startCanvas.canvasY, currentCanvas.canvasY),
      bottom: Math.max(startCanvas.canvasY, currentCanvas.canvasY),
    };

    for (const node of this.editor.getNodes()) {
      if (this.nodeIntersectsSelection(node, selectionRect)) {
        await this.selectableNodes.select(node.id, true);
      }
    }

    await this.callbacks.onSelectionDragFinished?.(selectionRect);
  }

  nodeIntersectsSelection(node, selectionRect) {
    const view = this.area.nodeViews.get(node.id);
    if (!view) {
      return false;
    }

    const width = node.width || this.getNodeWidth(node.workflowData || node);
    const height = node.height || this.getNodeHeight(node.workflowData || node);
    const nodeRect = {
      left: view.position.x,
      right: view.position.x + width,
      top: view.position.y,
      bottom: view.position.y + height,
    };

    return !(
      nodeRect.right < selectionRect.left ||
      nodeRect.left > selectionRect.right ||
      nodeRect.bottom < selectionRect.top ||
      nodeRect.top > selectionRect.bottom
    );
  }

  getSelectedIds() {
    const nodeIds = new Set();
    const stickyNoteIds = new Set();
    for (const entity of this.selector.entities.values()) {
      if (entity.label === "sticky-note") {
        stickyNoteIds.add(entity.id);
      } else {
        nodeIds.add(entity.id);
      }
    }
    return { nodeIds, stickyNoteIds };
  }

  async selectStickyNote(
    clientId,
    stickyCallbacks,
    { accumulate = this.accumulating.active() } = {}
  ) {
    const entityKey = `sticky-note_${clientId}`;

    if (this.selector.entities.has(entityKey)) {
      this.selector.pick({ id: clientId, label: "sticky-note" });
      return;
    }

    this.selector.pick({ id: clientId, label: "sticky-note" });
    await this.selector.add(
      {
        label: "sticky-note",
        id: clientId,
        translate(dx, dy) {
          stickyCallbacks.onStickyNoteTranslate?.(clientId, dx, dy);
        },
        unselect() {
          stickyCallbacks.onStickyNoteUnselect?.(clientId);
        },
      },
      accumulate
    );
  }

  isStickyNoteSelected(clientId) {
    return this.selector.entities.has(`sticky-note_${clientId}`);
  }

  async translateSelectedEntities(
    draggedId,
    draggedLabel,
    dx,
    dy,
    { labels = null } = {}
  ) {
    for (const entity of this.selector.entities.values()) {
      if (labels && !labels.includes(entity.label)) {
        continue;
      }
      if (entity.id === draggedId && entity.label === draggedLabel) {
        continue;
      }
      await entity.translate(dx, dy);
    }
  }

  outputIndexFor(sourceNode, connection) {
    return normalizeSourceOutputIndex(
      connection,
      Object.keys(sourceNode?.outputs || {})
    );
  }

  outputKeyFor(sourceNode, connection) {
    return (
      Object.keys(sourceNode?.outputs || {})[
        this.outputIndexFor(sourceNode, connection)
      ] || normalizeSourceOutput(connection.sourceOutput)
    );
  }

  inputKeyFor(targetNode, connection) {
    return (
      Object.keys(targetNode?.inputs || {})[
        normalizeTargetInputIndex(connection)
      ] || normalizeTargetInput(connection.targetInput)
    );
  }

  targetInputIndexFor(targetNode, connection) {
    if (connection.targetInputIndex != null) {
      return connection.targetInputIndex;
    }

    const inputKey = this.inputKeyFor(targetNode, connection);
    const targetNodeType =
      this.nodeTypesByIdentifier.get(targetNode?.workflowData?.type) ||
      targetNode?.workflowData?.type;

    if (
      nodeTypeInputUsesConnectionIndexes(
        targetNodeType,
        inputKey,
        targetNode?.workflowData
      )
    ) {
      return nextAvailableTargetInputIndex(
        this.editor.getConnections(),
        targetNode.id,
        connection
      );
    }

    return portIndexFromKey(
      connection.targetInput,
      Object.keys(targetNode?.inputs || {})
    );
  }

  annotateConnectionIndexes(connection) {
    const sourceNode = this.editor.getNode(
      connection.sourceClientId || connection.source
    );
    const targetNode = this.editor.getNode(
      connection.targetClientId || connection.target
    );

    connection.sourceOutputIndex = this.outputIndexFor(sourceNode, connection);
    connection.targetInputIndex = this.targetInputIndexFor(
      targetNode,
      connection
    );
    return connection;
  }

  buildDesiredGraphConnections(connections) {
    const graphConnections = [];
    const seen = new Set();

    for (const connection of connections) {
      const sourceNode = this.editor.getNode(connection.sourceClientId);
      const targetNode = this.editor.getNode(connection.targetClientId);
      if (!sourceNode || !targetNode) {
        continue;
      }

      const sourceOutputIndex = this.outputIndexFor(sourceNode, connection);
      const targetInputIndex = normalizeTargetInputIndex(connection);
      const key = graphConnectionKey({
        source: connection.sourceClientId,
        sourceOutputIndex,
        target: connection.targetClientId,
        targetInputIndex,
      });

      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      graphConnections.push({
        source: connection.sourceClientId,
        sourceOutput: this.outputKeyFor(sourceNode, connection),
        sourceOutputIndex,
        target: connection.targetClientId,
        targetInput: this.inputKeyFor(targetNode, connection),
        targetInputIndex,
      });
    }

    return graphConnections;
  }

  updateRendererGraphIndex(connections = this.editor.getConnections()) {
    this.renderer.graphIndex = buildWorkflowGraphIndex(
      this.editor.getNodes().map((node) => ({
        id: node.id,
        type: node.workflowData.type,
      })),
      connections.map((connection) =>
        this.annotateConnectionIndexes(connection)
      )
    );
  }

  async addNode(data) {
    const node = new this.WorkflowNode(data);
    await this.editor.addNode(node);
    if (data.position) {
      await this.area.translate(node.id, data.position);
    }
    return node;
  }

  async removeNode(clientId) {
    if (!this.editor.getNode(clientId)) {
      return;
    }

    const connections = this.editor
      .getConnections()
      .filter((c) => c.source === clientId || c.target === clientId);
    for (const conn of connections) {
      await this.editor.removeConnection(conn.id);
    }
    await this.editor.removeNode(clientId);
  }

  async addConnection(
    sourceClientId,
    sourceOutput,
    targetClientId,
    targetInput = "main",
    sourceOutputIndex = null,
    targetInputIndex = null
  ) {
    const sourceNode = this.editor.getNode(sourceClientId);
    const targetNode = this.editor.getNode(targetClientId);
    if (!sourceNode || !targetNode) {
      return;
    }

    const connection = new this.ClassicPreset.Connection(
      sourceNode,
      this.outputKeyFor(sourceNode, { sourceOutput, sourceOutputIndex }),
      targetNode,
      this.inputKeyFor(targetNode, { targetInput, targetInputIndex })
    );
    connection.sourceOutputIndex = this.outputIndexFor(sourceNode, {
      sourceOutput,
      sourceOutputIndex,
    });
    connection.targetInputIndex = this.targetInputIndexFor(targetNode, {
      targetInput,
      targetInputIndex,
    });

    await this.editor.addConnection(connection);
  }

  async syncState(nodes, connections) {
    this.isSyncing = true;
    try {
      const targetClientIds = new Set(nodes.map((n) => n.clientId));

      for (const node of [...this.editor.getNodes()]) {
        if (!targetClientIds.has(node.id)) {
          await this.removeNode(node.id);
        }
      }

      for (const nodeData of nodes) {
        const reteNode = this.editor.getNode(nodeData.clientId);

        if (!reteNode) {
          await this.addNode(nodeData);
          continue;
        }

        const currentInputKeys = Object.keys(reteNode.inputs || {});
        const nextInputKeys = this.inputKeysFor(nodeData);
        const inputsChanged =
          currentInputKeys.length !== nextInputKeys.length ||
          currentInputKeys.some((key, index) => key !== nextInputKeys[index]);

        if (reteNode.workflowData.type !== nodeData.type || inputsChanged) {
          await this.removeNode(nodeData.clientId);
          await this.addNode(nodeData);
          continue;
        }

        if (nodeData.position && !this.wasDragging) {
          const view = this.area.nodeViews.get(nodeData.clientId);
          if (view) {
            const pos = view.position;
            if (
              Math.abs(pos.x - nodeData.position.x) > 0.5 ||
              Math.abs(pos.y - nodeData.position.y) > 0.5
            ) {
              await this.area.translate(nodeData.clientId, nodeData.position);
            }
          }
        }

        const newLabel =
          this.getNodeLabel(nodeData) || nodeData.name || reteNode.label;
        const newWidth = this.getNodeWidth(nodeData);
        const newHeight = this.getNodeHeight(nodeData);
        const needsUpdate =
          reteNode.label !== newLabel ||
          reteNode.width !== newWidth ||
          reteNode.height !== newHeight ||
          JSON.stringify(reteNode.workflowData.configuration) !==
            JSON.stringify(nodeData.configuration);

        reteNode.workflowData = nodeData;
        reteNode.label = newLabel;
        reteNode.width = newWidth;
        reteNode.height = newHeight;

        if (needsUpdate && !this.wasDragging) {
          this.area.update("node", reteNode.id);
        }
      }

      const desiredGraphConnections =
        this.buildDesiredGraphConnections(connections);
      this.updateRendererGraphIndex(desiredGraphConnections);

      const desiredConnectionKeys = new Set(
        desiredGraphConnections.map((connection) =>
          graphConnectionKey(connection)
        )
      );
      const existingConnections = this.editor.getConnections();
      const existingConnectionKeys = new Map();

      for (const connection of existingConnections) {
        const key = graphConnectionKey(
          this.annotateConnectionIndexes(connection)
        );

        if (!desiredConnectionKeys.has(key)) {
          await this.editor.removeConnection(connection.id);
          continue;
        }

        existingConnectionKeys.set(key, connection.id);
      }

      for (const connection of desiredGraphConnections) {
        const key = graphConnectionKey(connection);

        if (existingConnectionKeys.has(key)) {
          continue;
        }

        await this.addConnection(
          connection.source,
          connection.sourceOutput,
          connection.target,
          connection.targetInput,
          connection.sourceOutputIndex,
          connection.targetInputIndex
        );
        existingConnectionKeys.set(key, true);
      }
    } finally {
      this.isSyncing = false;
    }

    this.renderer.scheduleConnectionUpdate();
  }

  async fitToView(extraRects) {
    const nodes = this.editor.getNodes();
    if (nodes.length === 0) {
      return;
    }

    const bbox = this.AreaExtensions.getBoundingBox(this.area, nodes);
    let { left: minX, top: minY, right: maxX, bottom: maxY } = bbox;

    const connectedOutputs = buildConnectedOutputsIndex(
      this.editor.getConnections()
    );
    for (const node of nodes) {
      const nodeConns = connectedOutputs.get(node.id);
      if (
        !Object.keys(node.outputs).some((key, outputIndex) => {
          return key !== "loop" && !nodeConns?.has(outputIndex);
        })
      ) {
        continue;
      }
      const view = this.area.nodeViews.get(node.id);
      if (view) {
        maxX = Math.max(maxX, view.position.x + (node.width || 0) + 48);
      }
    }

    for (const rect of extraRects || []) {
      minX = Math.min(minX, rect.x);
      minY = Math.min(minY, rect.y);
      maxX = Math.max(maxX, rect.x + rect.width);
      maxY = Math.max(maxY, rect.y + rect.height);
    }

    const bw = maxX - minX;
    const bh = maxY - minY;
    if (bw === 0 && bh === 0) {
      return;
    }

    const cx = (minX + maxX) / 2;
    const cy = (minY + maxY) / 2;
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;

    const padding = 0.9;
    const kw = bw > 0 ? w / bw : 1;
    const kh = bh > 0 ? h / bh : 1;
    const k = Math.min(kw * padding, kh * padding, 1.5);

    this.area.area.transform.x = w / 2 - cx * k;
    this.area.area.transform.y = h / 2 - cy * k;
    await this.area.area.zoom(k, 0, 0);
  }

  async zoomAtViewportCenter(newK) {
    const t = this.area.area.transform;
    const cx = this.container.clientWidth / 2;
    const cy = this.container.clientHeight / 2;
    const ox = (cx - t.x) * (1 - newK / t.k);
    const oy = (cy - t.y) * (1 - newK / t.k);
    await this.area.area.zoom(newK, ox, oy);
  }

  async autoArrange() {
    this.isAutoArranging = true;
    try {
      const allConns = this.editor.getConnections();
      const outgoing = buildOutgoingIndex(allConns, "source");
      const loopBodyIds = new Set(
        this.renderer.graphIndex.loopOwnerByNodeId.keys()
      );

      const removedConns = allConns.filter(
        (c) =>
          c.source === c.target ||
          loopBodyIds.has(c.source) ||
          loopBodyIds.has(c.target) ||
          (c.sourceOutput === LOOP_OUTPUT && c.source !== c.target)
      );
      for (const conn of removedConns) {
        await this.editor.removeConnection(conn.id);
      }

      await this.runDagreLayout({
        rankdir: "LR",
        nodesep: 30,
        ranksep: 20,
      });

      for (const conn of removedConns) {
        await this.editor.addConnection(conn);
      }

      const loopBodies = new Map();
      for (const [nodeId, owner] of this.renderer.graphIndex
        .loopOwnerByNodeId) {
        if (!loopBodies.has(owner)) {
          loopBodies.set(owner, new Set());
        }
        loopBodies.get(owner).add(nodeId);
      }

      for (const [loopId, bodyIds] of loopBodies) {
        const loopView = this.area.nodeViews.get(loopId);
        if (!loopView) {
          continue;
        }

        const ordered = [];
        const visited = new Set();
        let current = allConns.find(
          (c) =>
            c.source === loopId &&
            c.sourceOutput === LOOP_OUTPUT &&
            c.target !== loopId
        )?.target;
        while (current && bodyIds.has(current) && !visited.has(current)) {
          ordered.push(current);
          visited.add(current);
          current = outgoing
            .get(current)
            ?.find((c) => c.target !== loopId)?.target;
        }

        ordered.reverse();
        const orderedNodes = ordered
          .map((id) => this.editor.getNode(id))
          .filter(Boolean);
        const totalWidth =
          orderedNodes.reduce(
            (width, node) => width + (node.width || NODE_WIDTH),
            0
          ) +
          Math.max(0, orderedNodes.length - 1) * 50;
        let currentX = loopView.position.x + (NODE_WIDTH - totalWidth) / 2;

        for (const bodyNode of orderedNodes) {
          const bodyView = this.area.nodeViews.get(bodyNode.id);
          if (bodyView) {
            await bodyView.translate(currentX, loopView.position.y + 160);
          }
          currentX += (bodyNode.width || NODE_WIDTH) + 50;
        }
      }

      const positions = new Map();
      for (const node of this.editor.getNodes()) {
        const view = this.area.nodeViews.get(node.id);
        if (view) {
          positions.set(node.id, { x: view.position.x, y: view.position.y });
        }
      }
      return positions;
    } finally {
      this.isAutoArranging = false;
    }
  }

  async runDagreLayout({ rankdir = "LR", nodesep = 30, ranksep = 20 } = {}) {
    const graph = new this.dagre.graphlib.Graph();
    graph.setGraph({ rankdir, nodesep, ranksep });
    graph.setDefaultEdgeLabel(() => ({}));

    const nodes = this.editor.getNodes();
    for (const node of nodes) {
      graph.setNode(node.id, {
        width: node.width || NODE_WIDTH,
        height: node.height || 90,
      });
    }

    const connections = this.editor
      .getConnections()
      .filter(
        (conn) =>
          conn.source !== conn.target &&
          graph.hasNode(conn.source) &&
          graph.hasNode(conn.target)
      );
    for (const conn of connections) {
      graph.setEdge(conn.source, conn.target);
    }

    this.dagre.layout(graph, {
      constraints: this.branchOrderConstraints(connections),
    });

    await Promise.all(
      nodes.map((node) => {
        const { x, y, width, height } = graph.node(node.id);
        return this.area.translate(node.id, {
          x: x - width / 2,
          y: y - height / 2,
        });
      })
    );
  }

  // Dagre has no notion of ports and stacks a node's branch targets in an
  // arbitrary order; constrain siblings to follow the output port order
  // (e.g. if yes above no), like elk's port support used to.
  branchOrderConstraints(connections) {
    const constraints = [];
    const rightsByLeft = new Map();

    const wouldCycle = (left, right) => {
      const stack = [right];
      const seen = new Set();
      while (stack.length) {
        const current = stack.pop();
        if (current === left) {
          return true;
        }
        if (seen.has(current)) {
          continue;
        }
        seen.add(current);
        stack.push(...(rightsByLeft.get(current) || []));
      }
      return false;
    };

    for (const [sourceId, conns] of buildOutgoingIndex(connections, "source")) {
      const sourceNode = this.editor.getNode(sourceId);
      const targets = conns
        .sort(
          (a, b) =>
            this.outputIndexFor(sourceNode, a) -
              this.outputIndexFor(sourceNode, b) ||
            normalizeTargetInputIndex(a) - normalizeTargetInputIndex(b)
        )
        .map((conn) => conn.target)
        .filter((target, index, list) => list.indexOf(target) === index);

      for (let i = 0; i < targets.length - 1; i++) {
        const left = targets[i];
        const right = targets[i + 1];
        if (rightsByLeft.get(left)?.has(right) || wouldCycle(left, right)) {
          continue;
        }
        if (!rightsByLeft.has(left)) {
          rightsByLeft.set(left, new Set());
        }
        rightsByLeft.get(left).add(right);
        constraints.push({ left, right });
      }
    }

    return constraints;
  }

  get areaContentElement() {
    return this.area.area.content.holder;
  }

  get transform() {
    const { x, y, k } = this.area.area.transform;
    return { x, y, k };
  }

  get nodeCount() {
    return this.editor.getNodes().length;
  }

  containerToCanvas(localX, localY) {
    const { x, y, k } = this.area.area.transform;
    return { canvasX: (localX - x) / k, canvasY: (localY - y) / k };
  }

  viewportCenter() {
    const rect = this.container.getBoundingClientRect();
    return this.containerToCanvas(rect.width / 2, rect.height / 2);
  }

  destroy() {
    this.container.classList.remove("is-selecting");
    this.selectionBoxElement?.remove();
    this.selectionBoxElement = null;
    this.selectionDrag = null;
    this.shiftAbort?.abort();
    this.renderer.cancelScheduledConnectionUpdate();
    this.renderer.destroyMeasureSvg();
    this.area.destroy();
  }
}

export async function createReteEditor(container, options) {
  return ReteEditorBridge.create(container, options);
}
