import { trackedMap } from "@ember/reactive/collections";
import { cancel, later } from "@ember/runloop";
import loadRete from "discourse/lib/load-rete";
import { i18n } from "discourse-i18n";
import {
  nodeHeight,
  nodeLabel,
  nodeWidth,
} from "../../../lib/workflows/node-utils";
import {
  buildWorkflowGraphIndex,
  getConnectionKind,
  graphConnectionKey,
  normalizeSourceOutput,
} from "./rete-graph-index";
import {
  bezierPath,
  connectionToolbarPosition,
  loopBackLayout,
  loopBodyPath,
  positionArrowAtEnd,
} from "./rete-path-utils";

const SVG_NS = "http://www.w3.org/2000/svg";
const SVG_OVERLAY_STYLE =
  "overflow:visible;position:absolute;pointer-events:none;width:9999px;height:9999px";

function svgEl(tag, attrs) {
  const el = document.createElementNS(SVG_NS, tag);
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      el.setAttribute(k, v);
    }
  }
  return el;
}

function createOverlaySvg(className) {
  const svg = svgEl("svg");
  svg.classList.add(className);
  svg.style.cssText = SVG_OVERLAY_STYLE;
  return svg;
}

function outputKeysForType(type) {
  if (type === "condition:if" || type === "condition:filter") {
    return ["true", "false"];
  }
  if (type === "core:loop_over_items") {
    return ["done", "loop"];
  }
  return ["main"];
}

function createCustomRenderer(Scope, iconHTML, callbacks) {
  return class CustomRenderer extends Scope {
    nodeEntries = trackedMap();

    // Socket bridge: called from WorkflowNode's didInsert modifier
    onSocketRendered = (nodeId, side, key, socketOrOutputs, element) => {
      const socket =
        side === "input" ? socketOrOutputs : socketOrOutputs[key]?.socket;

      if (!socket || key === "loop") {
        return;
      }

      this.parentScope().emit({
        type: "render",
        data: { element, type: "socket", nodeId, side, key, socket },
      });
    };

    constructor() {
      super("workflow-renderer");
      this.iconHTML = iconHTML;
      this.onLoopAddNode = callbacks?.onLoopAddNode;
      this.onConnectionAddNode = callbacks?.onConnectionAddNode;
      this.onConnectionDelete = callbacks?.onConnectionDelete;
      this.onNodeDelete = callbacks?.onNodeDelete;
      this.onManualTrigger = callbacks?.onManualTrigger;
      this.connectionElements = new Map();
      this.connectionElementIds = new WeakMap();
      this.connectionUpdateFrame = null;
      this.graphIndex = buildWorkflowGraphIndex([], []);

      this.addPipe((context) => {
        if (!context || typeof context !== "object" || !("type" in context)) {
          return context;
        }

        switch (context.type) {
          case "render":
            return this.#handleRender(context);
          case "unmount": {
            const { element } = context.data;
            // Clean up node entry if this is a node element
            for (const [id, entry] of this.nodeEntries) {
              if (entry.element === element) {
                this.nodeEntries.delete(id);
                break;
              }
            }
            // Clean up connection entry
            const payloadId = this.connectionElementIds.get(element);
            if (payloadId != null) {
              this.connectionElements.delete(payloadId);
              this.connectionElementIds.delete(element);
            }
            break;
          }
          case "nodetranslated":
            this.scheduleConnectionUpdate();
            break;
        }

        return context;
      });
    }

    get nodeEntryList() {
      return [...this.nodeEntries.values()];
    }

    #handleRender(context) {
      if (context.data.filled) {
        return context;
      }

      const { data } = context;

      switch (data.type) {
        case "node": {
          const { element, payload } = data;
          element.classList.add("workflow-rete-node-view");
          this.nodeEntries.set(payload.id, { element, node: payload });
          return { ...context, data: { ...data, filled: true } };
        }
        case "connection":
          this.renderConnection(data);
          break;
        case "socket":
          break;
        default:
          return context;
      }

      return { ...context, data: { ...data, filled: true } };
    }

    scheduleConnectionUpdate() {
      if (this.connectionUpdateFrame) {
        return;
      }

      this.connectionUpdateFrame = requestAnimationFrame(() => {
        this.connectionUpdateFrame = null;
        this.updateAllConnections();
      });
    }

    cancelScheduledConnectionUpdate() {
      if (this.connectionUpdateFrame) {
        cancelAnimationFrame(this.connectionUpdateFrame);
        this.connectionUpdateFrame = null;
      }
    }

    getConnectionEntry(payloadId) {
      return this.connectionElements.get(payloadId) || null;
    }

    #registerEntry(element, payload, entryData) {
      const entry = {
        ...this.getConnectionEntry(payload.id),
        element,
        payload,
        ...entryData,
      };
      this.connectionElements.set(payload.id, entry);
      this.connectionElementIds.set(element, payload.id);
      return entry;
    }

    setGraphIndex(graphIndex) {
      this.graphIndex = graphIndex;
    }

    renderConnection(data) {
      const { element, payload } = data;
      const isPseudo = payload.isPseudo;
      const isLoopBack =
        !isPseudo &&
        payload.source === payload.target &&
        payload.sourceOutput === "loop";

      if (isLoopBack) {
        this.renderLoopBack(element, payload);
        return;
      }

      const entry = this.ensureConnectionEntry(element, payload, isPseudo);
      const pathResult = this.computeConnectionPathForPayload(payload, {
        explicitStart: data.start,
        explicitEnd: data.end,
      });

      if (pathResult) {
        this.applyConnectionLayout(entry, pathResult);
      }
    }

    ensureConnectionEntry(element, payload, isPseudo) {
      let svg = element.querySelector("svg.workflow-connection");

      if (!svg) {
        svg = createOverlaySvg("workflow-connection");

        const hitPath = svgEl("path", {
          fill: "none",
          stroke: "transparent",
          "stroke-width": "12",
        });
        hitPath.style.pointerEvents = "stroke";
        hitPath.style.cursor = "pointer";
        hitPath.classList.add("workflow-connection__hit");

        const visiblePath = svgEl("path", { fill: "none" });
        visiblePath.classList.add("workflow-connection__visible");

        if (isPseudo) {
          visiblePath.setAttribute("stroke", "var(--tertiary)");
          visiblePath.setAttribute("stroke-width", "2");
          visiblePath.setAttribute("stroke-dasharray", "6 3");
          visiblePath.setAttribute("opacity", "0.6");
        } else {
          visiblePath.setAttribute("stroke", "var(--primary-low-mid)");
          visiblePath.setAttribute("stroke-width", "2");
        }

        const arrowEl = svgEl("polygon", {
          points: "-4 -6, 8 0, -4 6",
          fill: isPseudo ? "var(--tertiary)" : "var(--primary-low-mid)",
        });
        arrowEl.classList.add("workflow-connection__arrow");

        svg.append(hitPath, visiblePath, arrowEl);

        let toolbarFo = null;
        if (!isPseudo) {
          toolbarFo = this.#createConnectionToolbar(payload.id);
          this.#setupToolbarHover(hitPath, toolbarFo);
          svg.appendChild(toolbarFo);
        }

        element.appendChild(svg);

        return this.#registerEntry(element, payload, {
          isLoopBack: false,
          svg,
          visiblePath,
          hitPath,
          arrowEl,
          toolbarFo,
        });
      }

      return this.#registerEntry(element, payload, {
        isLoopBack: false,
        svg,
        visiblePath: svg.querySelector(".workflow-connection__visible"),
        hitPath: svg.querySelector(".workflow-connection__hit"),
        arrowEl: svg.querySelector(".workflow-connection__arrow"),
        toolbarFo: svg.querySelector(".workflow-connection__toolbar-fo"),
      });
    }

    #createConnectionToolbar(payloadId) {
      const toolbarFo = svgEl("foreignObject", {
        width: "48",
        height: "22",
      });
      toolbarFo.classList.add("workflow-connection__toolbar-fo");

      const toolbar = document.createElement("div");
      toolbar.className = "workflow-canvas-toolbar --inline";

      const addBtn = document.createElement("button");
      addBtn.type = "button";
      addBtn.className = "workflow-canvas-toolbar__btn";
      addBtn.title = i18n("discourse_workflows.canvas.add_step");
      addBtn.innerHTML = this.iconHTML("plus");
      addBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        const entry = this.getConnectionEntry(payloadId);
        if (entry) {
          this.onConnectionAddNode?.(entry.payload, e);
        }
      });

      const deleteBtn = document.createElement("button");
      deleteBtn.type = "button";
      deleteBtn.className = "workflow-canvas-toolbar__btn";
      deleteBtn.title = i18n("discourse_workflows.canvas.remove_connection");
      deleteBtn.innerHTML = this.iconHTML("trash-can");
      deleteBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        const entry = this.getConnectionEntry(payloadId);
        if (entry) {
          this.onConnectionDelete?.(entry.payload);
        }
      });

      toolbar.append(addBtn, deleteBtn);
      toolbarFo.appendChild(toolbar);
      return toolbarFo;
    }

    #setupToolbarHover(hitPath, toolbarFo) {
      let hideTimer = null;

      const show = () => {
        cancel(hideTimer);
        toolbarFo.classList.add("--visible");
      };

      const scheduleHide = () => {
        hideTimer = later(() => {
          toolbarFo.classList.remove("--visible");
        }, 500);
      };

      hitPath.addEventListener("mouseenter", show);
      hitPath.addEventListener("mouseleave", scheduleHide);
      toolbarFo.addEventListener("mouseenter", show);
      toolbarFo.addEventListener("mouseleave", scheduleHide);
    }

    computeConnectionPathForPayload(
      payload,
      { explicitStart, explicitEnd } = {}
    ) {
      if (explicitStart || explicitEnd) {
        const startPos =
          explicitStart ||
          this.getSocketWorldPos(
            payload.source,
            "output",
            normalizeSourceOutput(payload.sourceOutput)
          );
        const endPos =
          explicitEnd ||
          this.getSocketWorldPos(payload.target, "input", "input");

        return startPos && endPos ? bezierPath(startPos, endPos) : null;
      }

      return this.computeConnectionPath(this.getConnectionEndpoints(payload));
    }

    computeConnectionPath(endpoints) {
      const { startPos, endPos } = endpoints;

      if (!startPos || !endPos) {
        return null;
      }

      if (endpoints.isLoopBody) {
        return loopBodyPath(startPos, endPos, "right");
      }

      if (endpoints.isLoopReturn) {
        return loopBodyPath(startPos, endPos, "left");
      }

      return bezierPath(startPos, endPos);
    }

    applyConnectionLayout(entry, pathResult) {
      entry.visiblePath.setAttribute("d", pathResult.d);
      entry.hitPath?.setAttribute("d", pathResult.d);

      if (pathResult.controlPoints) {
        if (entry.arrowEl) {
          positionArrowAtEnd(entry.arrowEl, pathResult.controlPoints);
        }

        if (entry.toolbarFo) {
          const { x, y } = connectionToolbarPosition(pathResult.controlPoints);
          entry.toolbarFo.setAttribute("x", String(x));
          entry.toolbarFo.setAttribute("y", String(y));
        }
      }
    }

    renderLoopBack(element, payload) {
      const entry = this.ensureLoopBackEntry(element, payload);
      const startPos = this.getSocketWorldPos(payload.source, "output", "loop");
      const endPos = this.getSocketWorldPos(payload.source, "input", "input");

      if (!startPos || !endPos) {
        return;
      }

      const layout = loopBackLayout(startPos, endPos);
      entry.visiblePath.setAttribute("d", layout.d);
      entry.arrowEl.setAttribute("points", layout.arrowPoints);
      entry.buttonFo.setAttribute("x", String(layout.buttonPosition.x));
      entry.buttonFo.setAttribute("y", String(layout.buttonPosition.y));
    }

    ensureLoopBackEntry(element, payload) {
      let svg = element.querySelector("svg.workflow-loop-back");

      if (!svg) {
        svg = createOverlaySvg("workflow-loop-back");

        const visiblePath = svgEl("path", {
          fill: "none",
          stroke: "var(--primary-low-mid)",
          "stroke-width": "2",
        });
        visiblePath.classList.add("workflow-loop-back__path");

        const arrowEl = svgEl("polygon", {
          fill: "var(--primary-low-mid)",
        });
        arrowEl.classList.add("workflow-loop-back__arrow");

        const buttonFo = svgEl("foreignObject", {
          width: "28",
          height: "28",
        });
        buttonFo.classList.add("workflow-loop-back__button-fo");

        const addBtn = document.createElement("button");
        addBtn.type = "button";
        addBtn.className = "workflow-loop-back__add-btn";
        addBtn.innerHTML = "+";
        addBtn.addEventListener("click", (e) => {
          e.stopPropagation();
          e.preventDefault();
          const entry = this.getConnectionEntry(payload.id);
          if (entry) {
            this.onLoopAddNode?.(entry.payload.source, e);
          }
        });

        buttonFo.appendChild(addBtn);
        svg.append(visiblePath, arrowEl, buttonFo);
        element.appendChild(svg);

        return this.#registerEntry(element, payload, {
          isLoopBack: true,
          svg,
          visiblePath,
          hitPath: null,
          arrowEl,
          buttonFo,
        });
      }

      return this.#registerEntry(element, payload, {
        isLoopBack: true,
        svg,
        visiblePath: svg.querySelector(".workflow-loop-back__path"),
        arrowEl: svg.querySelector(".workflow-loop-back__arrow"),
        buttonFo: svg.querySelector(".workflow-loop-back__button-fo"),
      });
    }

    getConnectionEndpoints(payload) {
      const { isLoopBody, isLoopReturn, isLoopChain } = getConnectionKind(
        this.graphIndex,
        payload
      );

      let startPos, endPos;

      if (isLoopBody) {
        // Loop->Body: LOOP socket (right) -> body's output socket (right)
        startPos = this.getSocketWorldPos(
          payload.source,
          "output",
          normalizeSourceOutput(payload.sourceOutput)
        );
        endPos = this.getSocketWorldPos(payload.target, "output", "main");
      } else if (isLoopChain) {
        // Body->Body: source's input (left) -> target's output (right)
        startPos = this.getSocketWorldPos(payload.source, "input", "input");
        endPos = this.getSocketWorldPos(
          payload.target,
          "output",
          normalizeSourceOutput(payload.sourceOutput)
        );
      } else if (isLoopReturn) {
        // Body->Loop: input (left) -> input (left)
        startPos = this.getSocketWorldPos(payload.source, "input", "input");
        endPos = this.getSocketWorldPos(payload.target, "input", "input");
      } else {
        startPos = this.getSocketWorldPos(
          payload.source,
          "output",
          normalizeSourceOutput(payload.sourceOutput)
        );
        endPos = this.getSocketWorldPos(payload.target, "input", "input");
      }

      return { startPos, endPos, isLoopBody, isLoopReturn, isLoopChain };
    }

    getSocketWorldPos(nodeId, side, key) {
      const area = this.parentScope();
      const nodeView = area.nodeViews.get(nodeId);
      if (!nodeView) {
        return null;
      }

      const nodeEl = nodeView.element.querySelector(".workflow-rete-node");
      if (!nodeEl) {
        return null;
      }

      let socketEl;
      if (side === "input") {
        socketEl = nodeEl.querySelector(".workflow-rete-node__socket.--input");
      } else {
        socketEl = nodeEl.querySelector(
          `.workflow-rete-node__socket.--output[data-socket-key="${key}"]`
        );
      }

      const pos = nodeView.position;

      if (socketEl) {
        // Replicate rete-render-utils getElementCenter:
        // walk offsetParent chain from socket to node view element,
        // accumulating offsetLeft/Top + clientLeft/Top (borders)
        const viewEl = nodeView.element;
        let x = socketEl.offsetLeft;
        let y = socketEl.offsetTop;
        let current = socketEl.offsetParent;

        while (current && current !== viewEl) {
          x += current.offsetLeft + current.clientLeft;
          y += current.offsetTop + current.clientTop;
          current = current.offsetParent;
        }

        let finalX = pos.x + x + socketEl.offsetWidth / 2;
        const pill = socketEl.querySelector(".workflow-rete-node__port-pill");
        if (pill) {
          finalX += pill.offsetWidth + 12;
        }

        return {
          x: finalX,
          y: pos.y + y + socketEl.offsetHeight / 2,
        };
      }

      // Fallback
      const height = nodeEl.offsetHeight;

      if (side === "input") {
        return { x: pos.x, y: pos.y + height / 2 };
      }

      return {
        x: pos.x + nodeEl.offsetWidth,
        y: pos.y + height / 2,
      };
    }

    updateAllConnections() {
      this.cancelScheduledConnectionUpdate();

      for (const [, entry] of this.connectionElements) {
        if (entry.payload.isPseudo) {
          continue;
        }

        if (entry.isLoopBack) {
          this.renderLoopBack(entry.element, entry.payload);
          continue;
        }

        const endpoints = this.getConnectionEndpoints(entry.payload);
        const pathResult = this.computeConnectionPath(endpoints);

        if (pathResult) {
          this.applyConnectionLayout(entry, pathResult);
        }
      }
    }
  };
}

export async function createReteEditor(container, { iconHTML, callbacks }) {
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
  } = await loadRete();

  const socket = new ClassicPreset.Socket("workflow");

  class WorkflowNode extends ClassicPreset.Node {
    constructor(data) {
      super(nodeLabel(data) || data.name || "Node");
      this.workflowData = data;
      this.width = nodeWidth();
      this.height = nodeHeight(data);

      if (!data.type?.startsWith("trigger:")) {
        // Loop nodes need both the upstream entry edge and one or more loop-back
        // edges from the body, so the input must allow multiple connections.
        this.addInput(
          "input",
          new ClassicPreset.Input(
            socket,
            "",
            data.type === "core:loop_over_items"
          )
        );
      }

      for (const key of outputKeysForType(data.type)) {
        this.addOutput(key, new ClassicPreset.Output(socket, key, true));
      }
    }
  }

  const CustomRenderer = createCustomRenderer(Scope, iconHTML, {
    onLoopAddNode: (reteNodeId, event) => {
      const clientId = reteToClient.get(reteNodeId);
      if (clientId) {
        callbacks.onLoopAddNode?.(clientId, event);
      }
    },
    onNodeDelete: (clientId) => {
      if (!isSyncing) {
        callbacks.onNodeDelete?.(clientId);
      }
    },
    onConnectionAddNode: (payload, event) => {
      if (isSyncing) {
        return;
      }
      const sourceClientId = reteToClient.get(payload.source);
      const targetClientId = reteToClient.get(payload.target);
      if (sourceClientId && targetClientId) {
        callbacks.onConnectionAddNode?.(
          sourceClientId,
          payload.sourceOutput,
          targetClientId,
          event
        );
      }
    },
    onConnectionDelete: (payload) => {
      if (isSyncing) {
        return;
      }
      const sourceClientId = reteToClient.get(payload.source);
      const targetClientId = reteToClient.get(payload.target);
      if (sourceClientId && targetClientId) {
        callbacks.onConnectionDelete?.(
          sourceClientId,
          payload.sourceOutput,
          targetClientId
        );
      }
    },
    onManualTrigger: (clientId) => {
      callbacks.onManualTrigger?.(clientId);
    },
  });

  const editor = new NodeEditor();
  const area = new AreaPlugin(container);
  const connectionPlugin = new ConnectionPlugin();
  const renderer = new CustomRenderer();

  connectionPlugin.addPreset(ConnectionPresets.classic.setup());

  const arrange = new AutoArrangePlugin();
  arrange.addPreset(ArrangePresets.classic.setup());

  editor.use(area);
  area.use(connectionPlugin);
  area.use(renderer);
  area.use(arrange);
  area.area.setZoomHandler(new Zoom(0.03));

  AreaExtensions.simpleNodesOrder(area);

  const selector = AreaExtensions.selector();
  const accumulating = { active: () => false };
  AreaExtensions.selectableNodes(area, selector, { accumulating });

  // Track syncing to avoid feedback loops
  let isSyncing = false;
  let wasDragging = false;
  let lastPickedNode = null;
  let lastPickedTime = 0;
  const nodeMap = new Map(); // clientId -> reteNodeId
  const reteToClient = new Map(); // reteNodeId -> clientId

  function clientConnectionKey(connection) {
    return graphConnectionKey({
      source: connection.sourceClientId,
      sourceOutput: normalizeSourceOutput(connection.sourceOutput),
      target: connection.targetClientId,
    });
  }

  function editorConnectionKey(connection) {
    const sourceClientId = reteToClient.get(connection.source);
    const targetClientId = reteToClient.get(connection.target);

    if (!sourceClientId || !targetClientId) {
      return null;
    }

    return graphConnectionKey({
      source: sourceClientId,
      sourceOutput: normalizeSourceOutput(connection.sourceOutput),
      target: targetClientId,
    });
  }

  function buildDesiredGraphConnections(connections) {
    const graphConnections = [];
    const seen = new Set();

    for (const connection of connections) {
      const source = nodeMap.get(connection.sourceClientId);
      const target = nodeMap.get(connection.targetClientId);

      if (source == null || target == null) {
        continue;
      }

      const graphConnection = {
        source,
        sourceOutput: normalizeSourceOutput(connection.sourceOutput),
        target,
      };
      const key = graphConnectionKey(graphConnection);

      if (seen.has(key)) {
        continue;
      }

      seen.add(key);
      graphConnections.push(graphConnection);
    }

    return graphConnections;
  }

  function currentGraphConnections() {
    return editor.getConnections().map((connection) => ({
      source: connection.source,
      sourceOutput: normalizeSourceOutput(connection.sourceOutput),
      target: connection.target,
    }));
  }

  function updateRendererGraphIndex(connections = currentGraphConnections()) {
    renderer.setGraphIndex(
      buildWorkflowGraphIndex(
        editor.getNodes().map((node) => ({
          id: node.id,
          type: node.workflowData.type,
        })),
        connections
      )
    );
  }

  // Listen to area events (node dragging, picking, zoom)
  area.addPipe((context) => {
    if (isSyncing) {
      return context;
    }

    switch (context.type) {
      case "nodetranslated": {
        const clientId = reteToClient.get(context.data.id);
        if (clientId) {
          callbacks.onNodeDragged?.(clientId, context.data.position);
          if (!wasDragging) {
            container.classList.add("--dragging");
          }
          wasDragging = true;
        }
        break;
      }

      case "nodepicked": {
        const pickedId = context.data.id;
        const clientId = reteToClient.get(pickedId);

        if (clientId) {
          const now = Date.now();
          if (lastPickedNode === clientId && now - lastPickedTime < 400) {
            callbacks.onNodeDoubleClick?.(clientId);
            lastPickedNode = null;
            lastPickedTime = 0;
          } else {
            lastPickedNode = clientId;
            lastPickedTime = now;
          }
          callbacks.onNodePicked?.(clientId);
        }
        break;
      }

      case "pointerup":
        if (wasDragging) {
          wasDragging = false;
          container.classList.remove("--dragging");
          callbacks.onNodeDragEnd?.();
        }
        break;

      case "pointerdown": {
        const target = context.data.event.target;
        if (!target?.closest?.(".workflow-rete-node")) {
          callbacks.onCanvasPointerDown?.(context.data.event);
        }
        break;
      }

      case "zoomed":
        callbacks.onZoomed?.(context.data.zoom);
        break;
    }

    return context;
  });

  // Listen to connection events
  editor.addPipe((context) => {
    if (isSyncing) {
      return context;
    }

    if (
      context.type === "connectioncreated" ||
      context.type === "connectionremoved"
    ) {
      updateRendererGraphIndex();
      renderer.scheduleConnectionUpdate();

      if (context.type === "connectioncreated") {
        const conn = context.data;
        const sourceClientId = reteToClient.get(conn.source);
        const targetClientId = reteToClient.get(conn.target);
        if (sourceClientId && targetClientId) {
          callbacks.onConnectionCreated?.(
            sourceClientId,
            conn.sourceOutput,
            targetClientId
          );
        }
      }
    }

    return context;
  });

  async function addNode(data) {
    const node = new WorkflowNode(data);
    await editor.addNode(node);
    if (data.position) {
      await area.translate(node.id, data.position);
    }
    nodeMap.set(data.clientId, node.id);
    reteToClient.set(node.id, data.clientId);
    return node;
  }

  async function removeNode(clientId) {
    const reteId = nodeMap.get(clientId);
    if (reteId == null) {
      return;
    }

    const connections = editor
      .getConnections()
      .filter((c) => c.source === reteId || c.target === reteId);
    for (const conn of connections) {
      await editor.removeConnection(conn.id);
    }
    await editor.removeNode(reteId);
    nodeMap.delete(clientId);
    reteToClient.delete(reteId);
  }

  async function addConnection(sourceClientId, sourceOutput, targetClientId) {
    const sourceReteId = nodeMap.get(sourceClientId);
    const targetReteId = nodeMap.get(targetClientId);
    if (sourceReteId == null || targetReteId == null) {
      return;
    }

    const sourceNode = editor.getNode(sourceReteId);
    const targetNode = editor.getNode(targetReteId);
    if (!sourceNode || !targetNode) {
      return;
    }

    if (
      !targetNode.hasInput("input") ||
      !sourceNode.hasOutput(normalizeSourceOutput(sourceOutput))
    ) {
      return;
    }

    const conn = new ClassicPreset.Connection(
      sourceNode,
      normalizeSourceOutput(sourceOutput),
      targetNode,
      "input"
    );
    await editor.addConnection(conn);
  }

  async function syncState(nodes, connections) {
    isSyncing = true;
    try {
      const targetClientIds = new Set(nodes.map((n) => n.clientId));

      // Remove nodes not in target
      for (const clientId of [...nodeMap.keys()]) {
        if (!targetClientIds.has(clientId)) {
          await removeNode(clientId);
        }
      }

      // Add new nodes and recreate nodes whose type changed
      for (const nodeData of nodes) {
        const reteId = nodeMap.get(nodeData.clientId);
        const reteNode = reteId != null ? editor.getNode(reteId) : null;

        if (!reteNode) {
          await addNode(nodeData);
          continue;
        }

        if (reteNode.workflowData.type !== nodeData.type) {
          await removeNode(nodeData.clientId);
          await addNode(nodeData);
          continue;
        }

        // Update position if changed, but not while the user is dragging
        if (nodeData.position && !wasDragging) {
          const view = area.nodeViews.get(reteId);
          if (view) {
            const pos = view.position;
            if (
              Math.abs(pos.x - nodeData.position.x) > 0.5 ||
              Math.abs(pos.y - nodeData.position.y) > 0.5
            ) {
              await area.translate(reteId, nodeData.position);
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

        if (needsUpdate && !wasDragging) {
          area.update("node", reteNode.id);
        }
      }

      const desiredGraphConnections = buildDesiredGraphConnections(connections);
      updateRendererGraphIndex(desiredGraphConnections);

      const desiredConnectionKeys = new Set(
        connections
          .filter(
            (connection) =>
              nodeMap.has(connection.sourceClientId) &&
              nodeMap.has(connection.targetClientId)
          )
          .map(clientConnectionKey)
      );
      const existingConnections = editor.getConnections();
      const existingConnectionKeys = new Map();

      for (const connection of existingConnections) {
        const key = editorConnectionKey(connection);

        if (!key || !desiredConnectionKeys.has(key)) {
          await editor.removeConnection(connection.id);
          continue;
        }

        existingConnectionKeys.set(key, connection.id);
      }

      for (const connection of connections) {
        const key = clientConnectionKey(connection);

        if (existingConnectionKeys.has(key)) {
          continue;
        }

        await addConnection(
          connection.sourceClientId,
          normalizeSourceOutput(connection.sourceOutput),
          connection.targetClientId
        );
        existingConnectionKeys.set(key, true);
      }
    } finally {
      isSyncing = false;
    }

    // Wait for layout before measuring sockets, but collapse multiple requests.
    renderer.scheduleConnectionUpdate();
  }

  async function fitToView(extraRects) {
    const nodes = editor.getNodes();
    if (nodes.length === 0) {
      return;
    }

    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;

    for (const node of nodes) {
      const view = area.nodeViews.get(node.id);
      if (!view) {
        continue;
      }

      const { x, y } = view.position;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x + (node.width || 0));
      maxY = Math.max(maxY, y + (node.height || 0));
    }

    if (extraRects) {
      for (const rect of extraRects) {
        minX = Math.min(minX, rect.x);
        minY = Math.min(minY, rect.y);
        maxX = Math.max(maxX, rect.x + rect.width);
        maxY = Math.max(maxY, rect.y + rect.height);
      }
    }

    if (!isFinite(minX)) {
      return;
    }

    const bw = maxX - minX;
    const bh = maxY - minY;
    const cx = (minX + maxX) / 2;
    const cy = (minY + maxY) / 2;
    const w = container.clientWidth;
    const h = container.clientHeight;

    const padding = 0.9;
    const kw = bw > 0 ? w / bw : 1;
    const kh = bh > 0 ? h / bh : 1;
    const k = Math.min(kw * padding, kh * padding, 1.5);

    area.area.transform.x = w / 2 - cx * k;
    area.area.transform.y = h / 2 - cy * k;
    await area.area.zoom(k, 0, 0);
  }

  function getZoom() {
    return area.area.transform.k;
  }

  async function zoomAtViewportCenter(newK) {
    const t = area.area.transform;
    const cx = container.clientWidth / 2;
    const cy = container.clientHeight / 2;
    const wx = (cx - t.x) / t.k;
    const wy = (cy - t.y) / t.k;
    area.area.transform.x = cx - wx * newK;
    area.area.transform.y = cy - wy * newK;
    await area.area.zoom(newK, 0, 0);
  }

  async function autoArrange() {
    await arrange.layout({
      options: {
        "elk.algorithm": "layered",
        "elk.direction": "RIGHT",
        "elk.spacing.nodeNode": "60",
        "elk.layered.spacing.nodeNodeBetweenLayers": "80",
      },
    });

    const positions = new Map();
    for (const [clientId, reteId] of nodeMap) {
      const view = area.nodeViews.get(reteId);
      if (view) {
        positions.set(clientId, { x: view.position.x, y: view.position.y });
      }
    }
    return positions;
  }

  function destroy() {
    renderer.cancelScheduledConnectionUpdate();
    area.destroy();
  }

  return {
    editor,
    area,
    renderer,
    nodeMap,
    reteToClient,
    addNode,
    removeNode,
    addConnection,
    syncState,
    fitToView,
    autoArrange,
    getZoom,
    zoomAtViewportCenter,
    destroy,
  };
}
