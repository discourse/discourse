import loadRete from "discourse/lib/load-rete";
import {
  buildConnectedOutputsIndex,
  buildOutgoingIndex,
  buildWorkflowGraphIndex,
  graphConnectionKey,
  LOOP_OUTPUT,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";
import { nodeTypeOutputKeys } from "../../../lib/workflows/node-types";
import {
  NODE_WIDTH,
  nodeHeight,
  nodeLabel,
} from "../../../lib/workflows/node-utils";
import { createCustomRenderer } from "./custom-renderer";

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
      AutoArrangePlugin,
      ArrangePresets,
      classicConnectionPath,
      getElementCenter,
    } = await loadRete();

    const socket = new ClassicPreset.Socket("workflow");
    const nodeTypesByIdentifier = new Map(
      (nodeTypes || []).map((nodeType) => [nodeType.identifier, nodeType])
    );

    class WorkflowNode extends ClassicPreset.Node {
      constructor(data) {
        super(nodeLabel(data) || data.name || "Node");
        this.id = data.clientId;
        this.workflowData = data;
        this.width = NODE_WIDTH;
        this.height = nodeHeight(data);

        if (!data.type?.startsWith("trigger:")) {
          this.addInput(
            "input",
            new ClassicPreset.Input(
              socket,
              "",
              data.type === "core:loop_over_items"
            )
          );
        }

        for (const key of nodeTypeOutputKeys(
          nodeTypesByIdentifier.get(data.type) || data.type
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

    connectionPlugin.addPreset(ConnectionPresets.classic.setup());

    const arrange = new AutoArrangePlugin();
    arrange.addPreset(ArrangePresets.classic.setup());

    editor.use(area);
    area.use(connectionPlugin);
    area.use(renderer);
    area.use(arrange);
    area.area.setZoomHandler(new Zoom(0.05));

    AreaExtensions.simpleNodesOrder(area);

    class ToggleSelector extends AreaExtensions.Selector {
      async add(entity, accumulate) {
        if (accumulate && this.entities.has(`${entity.label}_${entity.id}`)) {
          await this.remove(entity);
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
        const target = context.data.event.target;
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
      arrange,
      container,
      callbacks,
      WorkflowNode,
      ClassicPreset,
      AreaExtensions,
      accumulating,
      shiftAbort,
    });

    renderer.onNodeDelete = (clientId) => {
      if (!bridge._isSyncing) {
        callbacks.onNodeDelete?.(clientId);
      }
    };

    bridge._setupPipes();
    return bridge;
  }

  constructor({
    editor,
    area,
    renderer,
    selector,
    selectableNodes,
    connectionPlugin,
    arrange,
    container,
    callbacks,
    WorkflowNode,
    ClassicPreset,
    AreaExtensions,
    accumulating,
    shiftAbort,
  }) {
    this.editor = editor;
    this.area = area;
    this.renderer = renderer;
    this.selector = selector;
    this.selectableNodes = selectableNodes;
    this._connectionPlugin = connectionPlugin;
    this._arrange = arrange;
    this._container = container;
    this._callbacks = callbacks;
    this._accumulating = accumulating;
    this._shiftAbort = shiftAbort;
    this._WorkflowNode = WorkflowNode;
    this._ClassicPreset = ClassicPreset;
    this._AreaExtensions = AreaExtensions;
    this._isSyncing = false;
    this._wasDragging = false;
    this._lastPickedId = null;
    this._lastPickedTime = 0;
  }

  _setupPipes() {
    this.area.addPipe((context) => {
      if (this._isSyncing) {
        return context;
      }

      switch (context.type) {
        case "nodetranslated":
          this._callbacks.onNodeDragged?.(
            context.data.id,
            context.data.position
          );
          if (!this._wasDragging) {
            this._container.classList.add("is-dragging");
          }
          this._wasDragging = true;
        // falls through to emit transform
        case "translated":
        case "zoomed": {
          const { x, y, k } = this.area.area.transform;
          this._callbacks.onTransformChanged?.({ x, y, k });
          break;
        }

        case "nodepicked": {
          this._callbacks.onNodePicked?.();
          const now = Date.now();
          const pickedId = context.data.id;
          if (
            pickedId === this._lastPickedId &&
            now - this._lastPickedTime < 500
          ) {
            this._callbacks.onNodeDoubleClick?.(pickedId);
            this._lastPickedId = null;
          } else {
            this._lastPickedId = pickedId;
          }
          this._lastPickedTime = now;
          break;
        }

        case "pointerup":
          if (this._wasDragging) {
            this._wasDragging = false;
            this._container.classList.remove("is-dragging");
            this._callbacks.onNodeDragEnd?.();
          }
          break;

        case "pointerdown": {
          const target = context.data.event.target;
          if (!target?.closest?.(".workflow-rete-node")) {
            this._callbacks.onCanvasPointerDown?.(context.data.event);
          }
          break;
        }
      }

      return context;
    });

    this.editor.addPipe((context) => {
      if (this._isSyncing) {
        return context;
      }

      if (
        context.type === "connectioncreated" ||
        context.type === "connectionremoved"
      ) {
        this._updateRendererGraphIndex();
        this.renderer.scheduleConnectionUpdate();

        if (context.type === "connectioncreated") {
          const conn = context.data;
          this._callbacks.onConnectionCreated?.(
            conn.source,
            conn.sourceOutput,
            conn.target
          );
        }
      }

      return context;
    });
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

  async selectStickyNote(clientId, stickyCallbacks) {
    const accumulate = this._accumulating.active();
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

  async translateSelectedEntities(draggedId, draggedLabel, dx, dy) {
    for (const entity of this.selector.entities.values()) {
      if (entity.id === draggedId && entity.label === draggedLabel) {
        continue;
      }
      await entity.translate(dx, dy);
    }
  }

  _connectionKeyFromClientIds(connection) {
    return graphConnectionKey({
      source: connection.sourceClientId,
      sourceOutput: connection.sourceOutput,
      target: connection.targetClientId,
    });
  }

  _buildDesiredGraphConnections(connections) {
    const graphConnections = [];
    const seen = new Set();

    for (const connection of connections) {
      if (
        !this.editor.getNode(connection.sourceClientId) ||
        !this.editor.getNode(connection.targetClientId)
      ) {
        continue;
      }

      const key = this._connectionKeyFromClientIds(connection);
      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      graphConnections.push({
        source: connection.sourceClientId,
        sourceOutput: normalizeSourceOutput(connection.sourceOutput),
        target: connection.targetClientId,
      });
    }

    return graphConnections;
  }

  _updateRendererGraphIndex(connections = this.editor.getConnections()) {
    this.renderer.graphIndex = buildWorkflowGraphIndex(
      this.editor.getNodes().map((node) => ({
        id: node.id,
        type: node.workflowData.type,
      })),
      connections
    );
  }

  async _addNode(data) {
    const node = new this._WorkflowNode(data);
    await this.editor.addNode(node);
    if (data.position) {
      await this.area.translate(node.id, data.position);
    }
    return node;
  }

  async _removeNode(clientId) {
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

  async _addConnection(sourceClientId, sourceOutput, targetClientId) {
    const sourceNode = this.editor.getNode(sourceClientId);
    const targetNode = this.editor.getNode(targetClientId);
    if (!sourceNode || !targetNode) {
      return;
    }

    await this.editor.addConnection(
      new this._ClassicPreset.Connection(
        sourceNode,
        normalizeSourceOutput(sourceOutput),
        targetNode,
        "input"
      )
    );
  }

  async syncState(nodes, connections) {
    this._isSyncing = true;
    try {
      const targetClientIds = new Set(nodes.map((n) => n.clientId));

      for (const node of [...this.editor.getNodes()]) {
        if (!targetClientIds.has(node.id)) {
          await this._removeNode(node.id);
        }
      }

      for (const nodeData of nodes) {
        const reteNode = this.editor.getNode(nodeData.clientId);

        if (!reteNode) {
          await this._addNode(nodeData);
          continue;
        }

        if (reteNode.workflowData.type !== nodeData.type) {
          await this._removeNode(nodeData.clientId);
          await this._addNode(nodeData);
          continue;
        }

        if (nodeData.position && !this._wasDragging) {
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

        const newLabel = nodeLabel(nodeData) || nodeData.name || reteNode.label;
        const needsUpdate =
          reteNode.label !== newLabel ||
          JSON.stringify(reteNode.workflowData.configuration) !==
            JSON.stringify(nodeData.configuration);

        reteNode.workflowData = nodeData;
        reteNode.label = newLabel;

        if (needsUpdate && !this._wasDragging) {
          this.area.update("node", reteNode.id);
        }
      }

      const desiredGraphConnections =
        this._buildDesiredGraphConnections(connections);
      this._updateRendererGraphIndex(desiredGraphConnections);

      const desiredConnectionKeys = new Set(
        connections.map((c) => this._connectionKeyFromClientIds(c))
      );
      const existingConnections = this.editor.getConnections();
      const existingConnectionKeys = new Map();

      for (const connection of existingConnections) {
        const key = graphConnectionKey(connection);

        if (!desiredConnectionKeys.has(key)) {
          await this.editor.removeConnection(connection.id);
          continue;
        }

        existingConnectionKeys.set(key, connection.id);
      }

      for (const connection of connections) {
        const key = this._connectionKeyFromClientIds(connection);

        if (existingConnectionKeys.has(key)) {
          continue;
        }

        await this._addConnection(
          connection.sourceClientId,
          normalizeSourceOutput(connection.sourceOutput),
          connection.targetClientId
        );
        existingConnectionKeys.set(key, true);
      }
    } finally {
      this._isSyncing = false;
    }

    this.renderer.scheduleConnectionUpdate();
  }

  async fitToView(extraRects) {
    const nodes = this.editor.getNodes();
    if (nodes.length === 0) {
      return;
    }

    const bbox = this._AreaExtensions.getBoundingBox(this.area, nodes);
    let { left: minX, top: minY, right: maxX, bottom: maxY } = bbox;

    const connectedOutputs = buildConnectedOutputsIndex(
      this.editor.getConnections()
    );
    for (const node of nodes) {
      const nodeConns = connectedOutputs.get(node.id);
      if (
        !Object.keys(node.outputs).some(
          (key) => key !== "loop" && !nodeConns?.has(key)
        )
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
    const w = this._container.clientWidth;
    const h = this._container.clientHeight;

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
    const cx = this._container.clientWidth / 2;
    const cy = this._container.clientHeight / 2;
    const ox = (cx - t.x) * (1 - newK / t.k);
    const oy = (cy - t.y) * (1 - newK / t.k);
    await this.area.area.zoom(newK, ox, oy);
  }

  async autoArrange() {
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

    await this._arrange.layout({
      options: {
        "elk.algorithm": "layered",
        "elk.direction": "RIGHT",
        "elk.spacing.nodeNode": "30",
        "elk.layered.spacing.nodeNodeBetweenLayers": "20",
      },
    });

    for (const conn of removedConns) {
      await this.editor.addConnection(conn);
    }

    const loopBodies = new Map();
    for (const [nodeId, owner] of this.renderer.graphIndex.loopOwnerByNodeId) {
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
      const totalWidth = ordered.length * 180 - 50;
      const startX = loopView.position.x - totalWidth / 2 + 65;
      for (let i = 0; i < ordered.length; i++) {
        const bodyView = this.area.nodeViews.get(ordered[i]);
        if (bodyView) {
          await bodyView.translate(startX + i * 180, loopView.position.y + 160);
        }
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
    const rect = this._container.getBoundingClientRect();
    return this.containerToCanvas(rect.width / 2, rect.height / 2);
  }

  destroy() {
    this._shiftAbort?.abort();
    this.renderer.cancelScheduledConnectionUpdate();
    this.renderer.destroyMeasureSvg();
    this.area.destroy();
  }
}

export async function createReteEditor(container, options) {
  return ReteEditorBridge.create(container, options);
}
