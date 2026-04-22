import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  nodeTypeLabel,
  nodeTypePrimaryOutputKey,
} from "../../../lib/workflows/node-types";
import StickyNote, { STICKY_NOTE_TYPE } from "../../../models/sticky-note";
import WorkflowConnection from "../../../models/workflow-connection";
import WorkflowNode from "../../../models/workflow-node";
import WorkflowCanvas from "../canvas";
import NodePanel from "../canvas/node-panel";
import NodeConfigurator from "../node/configurator";
import { LOOP_NODE_TYPE, removeNodesFromGraph } from "./graph-utils";
import { createNode, generateNodeName } from "./node-factory";
import UndoManager from "./undo-manager";

export default class WorkflowsEditor extends Component {
  @service router;
  @service modal;
  @service workflowsNodeTypes;
  @service messageBus;

  @tracked canUndo = false;
  @tracked canRedo = false;
  @tracked nodePanelContext = null;
  @tracked nodePanelNodeTypes = null;
  @tracked nodePanelSearchTerm = "";
  @tracked autoArrangeRequest = 0;
  formApi = null;
  ignoreDirty = () => false;
  undoManager = new UndoManager();

  formData = {
    name:
      this.args.workflow.name ||
      i18n("discourse_workflows.default_workflow_name"),
    nodes: this.#initNodes(),
    connections: this.#mapServerConnections(),
    stickyNotes: this.#initStickyNotes(),
  };
  isUndoRedo = false;

  constructor() {
    super(...arguments);
    this.workflowsNodeTypes.lastExecutionNodeOutputs =
      this.args.workflow?.last_execution_node_outputs || null;
    this.#subscribeToExecutions();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.undoManager.destroy();
    this.#unsubscribeFromExecutions();
  }

  #subscribeToExecutions() {
    const workflowId = this.args.workflow?.id;
    if (!workflowId) {
      return;
    }
    this.executionChannel = `/discourse-workflows/workflow/${workflowId}`;
    this.messageBus.subscribe(this.executionChannel, (message) => {
      if (message.type === "execution_completed") {
        this.workflowsNodeTypes.lastExecutionNodeOutputs =
          message.last_execution_node_outputs;
      }
    });
  }

  #unsubscribeFromExecutions() {
    if (this.executionChannel) {
      this.messageBus.unsubscribe(this.executionChannel);
      this.executionChannel = null;
    }
  }

  #mapServerConnections() {
    return (this.args.workflow.connections || []).map(
      WorkflowConnection.create
    );
  }

  #initNodes() {
    return (this.args.workflow.nodes || [])
      .filter((node) => node.type !== STICKY_NOTE_TYPE)
      .map((node) =>
        WorkflowNode.create({
          ...node,
          position: this.#parsePosition(node.position),
        })
      );
  }

  #initStickyNotes() {
    const allNodes = this.args.workflow.nodes || [];
    return allNodes
      .filter((node) => node.type === STICKY_NOTE_TYPE)
      .map(StickyNote.fromNode);
  }

  #parsePosition(pos) {
    if (pos && typeof pos === "object" && "x" in pos && "y" in pos) {
      return { x: pos.x, y: pos.y };
    }
    return null;
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  #refreshUndoState() {
    this.canUndo = this.undoManager.canUndo;
    this.canRedo = this.undoManager.canRedo;
  }

  #syncFromServer() {
    const allServerNodes = this.args.workflow.nodes || [];
    const formNodes = this.formApi.get("nodes");

    const positionsByClientId = new Map(
      formNodes.map((n) => [n.clientId, n.position])
    );

    const nodes = allServerNodes
      .filter((n) => n.type !== STICKY_NOTE_TYPE)
      .map((serverNode) => {
        return WorkflowNode.create({
          ...serverNode,
          position:
            positionsByClientId.get(serverNode.clientId) ||
            this.#parsePosition(serverNode.position),
        });
      });

    const stickyNotes = allServerNodes
      .filter((n) => n.type === STICKY_NOTE_TYPE)
      .map(StickyNote.fromNode);

    this.formApi.set("nodes", nodes);
    this.formApi.set("connections", this.#mapServerConnections());
    this.formApi.set("stickyNotes", stickyNotes);
  }

  #captureGraphSnapshot() {
    return {
      nodes: structuredClone(this.formApi.get("nodes")),
      connections: structuredClone(this.formApi.get("connections")),
      stickyNotes: structuredClone(this.formApi.get("stickyNotes")),
    };
  }

  #captureUndo() {
    if (this.undoManager.hasPendingCapture) {
      return;
    }
    this.undoManager.captureBeforeState(this.#captureGraphSnapshot());
  }

  @action
  applySnapshot({ nodes, connections, stickyNotes }) {
    this.isUndoRedo = true;
    this.formApi.set("nodes", nodes);
    this.formApi.set("connections", connections);
    if (stickyNotes) {
      this.formApi.set("stickyNotes", stickyNotes);
    }
    this.handleSubmit();
  }

  @action
  async initializeUndo(area) {
    await this.undoManager.initialize(area, this.applySnapshot);
  }

  @action
  async undo() {
    await this.#undoRedoAction("undo");
  }

  @action
  async redo() {
    await this.#undoRedoAction("redo");
  }

  async #undoRedoAction(method) {
    await this.undoManager[method]();
    this.#refreshUndoState();
  }

  #isLoopSelfConnection(connection, clientId) {
    return (
      connection.sourceClientId === clientId &&
      connection.targetClientId === clientId &&
      connection.sourceOutput === "loop"
    );
  }

  #ensureLoopSelfConnection(connections, clientId, identifier) {
    if (identifier !== LOOP_NODE_TYPE) {
      return;
    }

    const hasBody = this.#hasLoopBodyConnection(connections, clientId);
    const selfIdx = connections.findIndex((c) =>
      this.#isLoopSelfConnection(c, clientId)
    );

    if (hasBody && selfIdx >= 0) {
      connections.splice(selfIdx, 1);
    } else if (!hasBody && selfIdx < 0) {
      connections.push({
        sourceClientId: clientId,
        targetClientId: clientId,
        sourceOutput: "loop",
      });
    }
  }

  #hasLoopBodyConnection(connections, loopNodeClientId) {
    return connections.some(
      (connection) =>
        connection.sourceClientId === loopNodeClientId &&
        connection.sourceOutput === "loop" &&
        connection.targetClientId !== loopNodeClientId
    );
  }

  #addNewNode(nodeType, position, configOverrides, wireConnections) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const newNode = createNode(nodeType.identifier, existingNodes, position, {
      typeVersion: nodeType.latest_version,
      configOverrides,
    });

    this.formApi.set("nodes", [...existingNodes, newNode]);

    const connections = [...this.formApi.get("connections")];
    const shouldAutoLayout = wireConnections(connections, newNode, nodeType);

    this.#ensureLoopSelfConnection(
      connections,
      newNode.clientId,
      nodeType.identifier
    );
    this.formApi.set("connections", connections);

    if (shouldAutoLayout) {
      this.autoArrangeRequest++;
    } else {
      this.handleSubmit();
    }
  }

  @action
  addNode(sourceClientId, sourceOutput, nodeType, configOverrides = null) {
    this.#addNewNode(
      nodeType,
      null,
      configOverrides,
      (connections, newNode) => {
        if (sourceClientId) {
          const existingIdx = connections.findIndex(
            (c) =>
              c.sourceClientId === sourceClientId &&
              c.sourceOutput === sourceOutput
          );

          if (existingIdx >= 0) {
            const existing = connections[existingIdx];
            connections.splice(existingIdx, 1);
            connections.push({
              sourceClientId,
              targetClientId: newNode.clientId,
              sourceOutput,
            });
            connections.push({
              sourceClientId: newNode.clientId,
              targetClientId: existing.targetClientId,
              sourceOutput: nodeTypePrimaryOutputKey(nodeType),
            });
          } else {
            connections.push({
              sourceClientId,
              targetClientId: newNode.clientId,
              sourceOutput,
            });
          }
        }
        return true;
      }
    );
  }

  @action
  addNodeAtPosition(
    sourceClientId,
    sourceOutput,
    nodeType,
    position,
    configOverrides = null
  ) {
    this.#addNewNode(
      nodeType,
      position,
      configOverrides,
      (connections, newNode) => {
        if (sourceClientId) {
          connections.push({
            sourceClientId,
            targetClientId: newNode.clientId,
            sourceOutput,
          });
        }
        return false;
      }
    );
  }

  @action
  insertNodeOnConnection(
    sourceClientId,
    sourceOutput,
    targetClientId,
    nodeType,
    configOverrides = null
  ) {
    const existingNodes = this.formApi.get("nodes");
    const sourceNode = existingNodes.find((n) => n.clientId === sourceClientId);
    const targetNode = existingNodes.find((n) => n.clientId === targetClientId);
    const position =
      sourceNode?.position && targetNode?.position
        ? {
            x: (sourceNode.position.x + targetNode.position.x) / 2,
            y: (sourceNode.position.y + targetNode.position.y) / 2,
          }
        : undefined;

    this.#addNewNode(
      nodeType,
      position,
      configOverrides,
      (connections, newNode) => {
        const existingIdx = connections.findIndex(
          (c) =>
            c.sourceClientId === sourceClientId &&
            c.sourceOutput === sourceOutput &&
            c.targetClientId === targetClientId
        );
        if (existingIdx >= 0) {
          connections.splice(existingIdx, 1);
        }

        connections.push({
          sourceClientId,
          targetClientId: newNode.clientId,
          sourceOutput,
        });
        connections.push({
          sourceClientId: newNode.clientId,
          targetClientId,
          sourceOutput: nodeTypePrimaryOutputKey(nodeType),
        });
        return true;
      }
    );
  }

  @action
  updateNodePosition(clientId, position) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    this.formApi.set(
      "nodes",
      nodes.map((n) => (n.clientId === clientId ? { ...n, position } : n))
    );
  }

  @action
  editNode(clientId) {
    const nodes = this.formApi.get("nodes");
    const connections = this.formApi.get("connections");
    const node = nodes.find((n) => n.clientId === clientId);
    if (!node) {
      return;
    }

    const triggerNode = nodes.find((n) => n.type?.startsWith("trigger:"));

    this.workflowsNodeTypes.setEditingContext(node, nodes, connections, {
      workflowId: this.args.workflow?.id,
    });

    this.modal.show(NodeConfigurator, {
      model: {
        node,
        nodes,
        connections,
        triggerType: triggerNode?.type,
        onSave: (configuration, name) =>
          this.updateNodeConfiguration(clientId, configuration, name),
        onRemove: () => this.removeNodes([clientId]),
      },
    });
  }

  @action
  createConnection(sourceClientId, sourceOutput, targetClientId) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    const connections = [...this.formApi.get("connections")];

    // Don't create duplicate connections
    const exists = connections.some(
      (c) =>
        c.sourceClientId === sourceClientId &&
        c.sourceOutput === sourceOutput &&
        c.targetClientId === targetClientId
    );
    if (exists) {
      return;
    }

    connections.push({ sourceClientId, targetClientId, sourceOutput });
    this.#ensureLoopSelfConnection(
      connections,
      sourceClientId,
      nodes.find((node) => node.clientId === sourceClientId)?.type
    );
    this.#ensureLoopSelfConnection(
      connections,
      targetClientId,
      nodes.find((node) => node.clientId === targetClientId)?.type
    );
    this.formApi.set("connections", connections);
    this.handleSubmit();
  }

  @action
  deleteConnection(sourceClientId, sourceOutput, targetClientId) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    const connections = [...this.formApi.get("connections")];
    const index = connections.findIndex(
      (c) =>
        c.sourceClientId === sourceClientId &&
        c.sourceOutput === sourceOutput &&
        c.targetClientId === targetClientId
    );

    if (index < 0) {
      return;
    }

    const conn = connections[index];
    if (conn.sourceClientId === conn.targetClientId) {
      return;
    }

    connections.splice(index, 1);
    this.#ensureLoopSelfConnection(
      connections,
      sourceClientId,
      nodes.find((node) => node.clientId === sourceClientId)?.type
    );
    this.#ensureLoopSelfConnection(
      connections,
      targetClientId,
      nodes.find((node) => node.clientId === targetClientId)?.type
    );
    this.formApi.set("connections", connections);
    this.handleSubmit();
  }

  @action
  removeNodes(clientIds) {
    this.#captureUndo();
    const updatedGraph = removeNodesFromGraph(
      this.formApi.get("nodes"),
      this.formApi.get("connections"),
      clientIds
    );

    this.formApi.set("nodes", updatedGraph.nodes);
    this.formApi.set("connections", updatedGraph.connections);
    this.handleSubmit();
  }

  @action
  removeSelected({ nodeIds, stickyNoteIds }) {
    this.#captureUndo();

    if (nodeIds.length > 0) {
      const updatedGraph = removeNodesFromGraph(
        this.formApi.get("nodes"),
        this.formApi.get("connections"),
        nodeIds
      );
      this.formApi.set("nodes", updatedGraph.nodes);
      this.formApi.set("connections", updatedGraph.connections);
    }

    if (stickyNoteIds.length > 0) {
      const stickyNoteIdSet = new Set(stickyNoteIds);
      const stickyNotes = this.formApi.get("stickyNotes");
      this.formApi.set(
        "stickyNotes",
        stickyNotes.filter((n) => !stickyNoteIdSet.has(n.clientId))
      );
    }

    this.handleSubmit();
  }

  @action
  addNodeToLoop(loopNodeClientId, nodeType, configOverrides = null) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const loopNode = existingNodes.find((n) => n.clientId === loopNodeClientId);
    const position = loopNode?.position
      ? { x: loopNode.position.x, y: loopNode.position.y + 120 }
      : null;

    const newNode = createNode(nodeType.identifier, existingNodes, position, {
      typeVersion: nodeType.latest_version,
      configOverrides,
    });
    const newNodeOutput = nodeTypePrimaryOutputKey(nodeType);

    const connections = [...this.formApi.get("connections")];

    if (!this.#hasLoopBodyConnection(connections, loopNodeClientId)) {
      connections.push({
        sourceClientId: loopNodeClientId,
        targetClientId: newNode.clientId,
        sourceOutput: "loop",
      });
      connections.push({
        sourceClientId: newNode.clientId,
        targetClientId: loopNodeClientId,
        sourceOutput: newNodeOutput,
      });
    } else {
      const loopBodyNodes = new Set();
      let currentConn = connections.find(
        (c) =>
          c.sourceClientId === loopNodeClientId &&
          c.sourceOutput === "loop" &&
          c.targetClientId !== loopNodeClientId
      );
      while (
        currentConn &&
        currentConn.targetClientId !== loopNodeClientId &&
        !loopBodyNodes.has(currentConn.targetClientId)
      ) {
        const nextSourceId = currentConn.targetClientId;
        loopBodyNodes.add(nextSourceId);
        currentConn = connections.find(
          (c) => c.sourceClientId === nextSourceId
        );
      }

      const loopBackIdx = connections.findIndex(
        (c) =>
          c.targetClientId === loopNodeClientId &&
          loopBodyNodes.has(c.sourceClientId)
      );

      if (loopBackIdx >= 0) {
        const loopBack = connections[loopBackIdx];
        const prevSourceId = loopBack.sourceClientId;
        const prevSourceOutput = loopBack.sourceOutput;
        connections.splice(loopBackIdx, 1);
        connections.push({
          sourceClientId: prevSourceId,
          targetClientId: newNode.clientId,
          sourceOutput: prevSourceOutput,
        });
        connections.push({
          sourceClientId: newNode.clientId,
          targetClientId: loopNodeClientId,
          sourceOutput: newNodeOutput,
        });
      }
    }

    this.#ensureLoopSelfConnection(
      connections,
      loopNodeClientId,
      loopNode?.type
    );

    this.formApi.set("nodes", [...existingNodes, newNode]);
    this.formApi.set("connections", connections);
    this.handleSubmit();
  }

  @action
  updateNodeConfiguration(clientId, configuration, name) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    this.formApi.set(
      "nodes",
      nodes.map((n) =>
        n.clientId === clientId
          ? { ...n, configuration, name: name || n.name }
          : n
      )
    );
    this.handleSubmit();
  }

  @action
  replaceTrigger(clientId, nodeType) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const replacement = createNode(nodeType.identifier, existingNodes, null, {
      typeVersion: nodeType.latest_version,
    });

    const nodes = existingNodes.map((n) =>
      n.clientId === clientId
        ? {
            ...n,
            type: replacement.type,
            type_version: replacement.type_version,
            name: replacement.name,
            configuration: replacement.configuration,
          }
        : n
    );

    this.formApi.set("nodes", nodes);
    this.handleSubmit();
  }

  @action
  importNodes(newNodes, newConnections, newStickyNotes) {
    this.#captureUndo();

    const existingNodes = this.formApi.get("nodes");
    const existingConnections = this.formApi.get("connections");

    this.formApi.set("nodes", [...existingNodes, ...newNodes]);
    this.formApi.set("connections", [
      ...existingConnections,
      ...newConnections,
    ]);

    if (newStickyNotes?.length) {
      const existingStickyNotes = this.formApi.get("stickyNotes");
      this.formApi.set("stickyNotes", [
        ...existingStickyNotes,
        ...newStickyNotes,
      ]);
    }

    this.handleSubmit();
  }

  @action
  autoLayout(positions) {
    this.#captureUndo();
    this.#applyNodePositions(positions);
    this.handleSubmit();
  }

  @action
  hydrateAutoLayout(positions) {
    this.#applyNodePositions(positions);
    this.handleSubmit();
  }

  #applyNodePositions(positions) {
    const nodes = this.formApi.get("nodes");
    const updatedNodes = nodes.map((node) => {
      const pos = positions.get(node.clientId);
      return pos ? { ...node, position: pos } : node;
    });
    this.formApi.set("nodes", updatedNodes);
  }

  // Sticky notes

  @action
  addStickyNote(position) {
    this.#captureUndo();
    const stickyNotes = [...this.formApi.get("stickyNotes")];
    stickyNotes.push(
      StickyNote.create({
        position: {
          x: position.canvasX ?? position.x ?? 0,
          y: position.canvasY ?? position.y ?? 0,
        },
      })
    );
    this.formApi.set("stickyNotes", stickyNotes);
    this.handleSubmit();
  }

  #updateStickyNote(clientId, updates) {
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.map((n) =>
        n.clientId === clientId ? { ...n, ...updates } : n
      )
    );
  }

  @action
  stickyNoteMove(clientId, newPosition) {
    this.#updateStickyNote(clientId, { position: newPosition });
  }

  @action
  stickyNoteResize(clientId, newSize) {
    this.#updateStickyNote(clientId, { size: newSize });
  }

  @action
  stickyNoteUpdateText(clientId, text) {
    this.#updateStickyNote(clientId, { text });
  }

  @action
  stickyNoteBeforeMutation() {
    this.#captureUndo();
  }

  @action
  stickyNoteChangeColor(clientId, color) {
    this.#captureUndo();
    this.#updateStickyNote(clientId, { color });
  }

  @action
  pasteEntities({ nodes, stickyNotes }) {
    this.#captureUndo();
    const offset = 20;

    if (nodes.length > 0) {
      const existingNodes = this.formApi.get("nodes");
      const newNodes = nodes.map((copiedNode) => {
        const position = copiedNode.position
          ? {
              x: copiedNode.position.x + offset,
              y: copiedNode.position.y + offset,
            }
          : null;
        return WorkflowNode.create({
          type: copiedNode.type,
          type_version: copiedNode.type_version,
          name: generateNodeName(copiedNode.type, existingNodes),
          configuration: structuredClone(copiedNode.configuration || {}),
          position,
        });
      });
      this.formApi.set("nodes", [...existingNodes, ...newNodes]);
    }

    if (stickyNotes.length > 0) {
      const newNotes = stickyNotes.map((copiedNote) =>
        StickyNote.create({
          position: {
            x: (copiedNote.position?.x ?? 0) + offset,
            y: (copiedNote.position?.y ?? 0) + offset,
          },
          size: copiedNote.size,
          color: copiedNote.color,
          text: copiedNote.text,
        })
      );
      const existingNotes = this.formApi.get("stickyNotes");
      this.formApi.set("stickyNotes", [...existingNotes, ...newNotes]);
    }

    this.handleSubmit();
  }

  @action
  async openNodePanel(context) {
    if (!this.nodePanelNodeTypes) {
      this.nodePanelNodeTypes = await this.workflowsNodeTypes.load();
    }
    this.nodePanelSearchTerm = "";
    this.nodePanelContext = context || {};
  }

  @action
  closeNodePanel() {
    this.nodePanelContext = null;
    this.nodePanelSearchTerm = "";
  }

  @action
  searchNodePanel(term) {
    this.nodePanelSearchTerm = term;
  }

  get filteredNodePanelTypes() {
    if (!this.nodePanelNodeTypes) {
      return [];
    }
    const term = this.nodePanelSearchTerm?.toLowerCase().trim();
    if (!term) {
      return this.nodePanelNodeTypes;
    }
    return this.nodePanelNodeTypes.filter((nt) => {
      const label = nodeTypeLabel(nt)?.toLowerCase() || "";
      return label.includes(term);
    });
  }

  @action
  selectNodeFromPanel(nodeType, operationValue = null) {
    const ctx = this.nodePanelContext;
    if (!ctx) {
      return;
    }

    const configOverrides = operationValue
      ? { operation: operationValue }
      : null;

    if (ctx.loopNodeClientId) {
      this.addNodeToLoop(ctx.loopNodeClientId, nodeType, configOverrides);
    } else if (ctx.sourceClientId) {
      const sourceNode = this.formApi
        .get("nodes")
        .find((n) => n.clientId === ctx.sourceClientId);
      const position = sourceNode?.position
        ? { x: sourceNode.position.x + 200, y: sourceNode.position.y }
        : null;
      if (position) {
        this.addNodeAtPosition(
          ctx.sourceClientId,
          ctx.sourceOutput,
          nodeType,
          position,
          configOverrides
        );
      } else {
        this.addNode(
          ctx.sourceClientId,
          ctx.sourceOutput,
          nodeType,
          configOverrides
        );
      }
    } else if (ctx.connectionSource) {
      this.insertNodeOnConnection(
        ctx.connectionSource,
        ctx.connectionSourceOutput,
        ctx.connectionTarget,
        nodeType,
        configOverrides
      );
    } else if (ctx.canvasX != null) {
      this.addNodeAtPosition(
        null,
        "main",
        nodeType,
        {
          x: ctx.canvasX,
          y: ctx.canvasY,
        },
        configOverrides
      );
    } else {
      this.addNode(null, "main", nodeType, configOverrides);
    }

    this.closeNodePanel();
  }

  @action
  async handleSubmit() {
    if (this.saving) {
      this.pendingSave = true;
      return;
    }

    this.saving = true;
    try {
      const name = this.formApi.get("name");
      const nodes = this.formApi.get("nodes");
      const connections = this.formApi.get("connections");
      const stickyNotes = this.formApi.get("stickyNotes");

      this.args.workflow.setProperties({
        name,
        nodes,
        connections,
        sticky_notes: stickyNotes || [],
      });

      await this.args.workflow.save();
      this.#syncFromServer();

      if (!this.isUndoRedo) {
        this.undoManager.commitAction(this.#captureGraphSnapshot());
      }
      this.isUndoRedo = false;
      this.#refreshUndoState();

      if (this.args.isNew) {
        this.router.transitionTo(
          "adminPlugins.show.discourse-workflows.show",
          this.args.workflow.id
        );
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
      if (this.pendingSave) {
        this.pendingSave = false;
        this.handleSubmit();
      }
    }
  }

  <template>
    <Form
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      @onRegisterApi={{this.registerApi}}
      @onDirtyCheck={{this.ignoreDirty}}
      class="workflows-editor"
      as |form transientData|
    >
      <div class="workflows-editor__body">
        <WorkflowCanvas
          @nodes={{transientData.nodes}}
          @connections={{transientData.connections}}
          @stickyNotes={{transientData.stickyNotes}}
          @workflowId={{@workflow.id}}
          @workflowName={{@workflow.name}}
          @autoArrangeRequest={{this.autoArrangeRequest}}
          @onUpdateNodePosition={{this.updateNodePosition}}
          @onEditNode={{this.editNode}}
          @onRemoveNodes={{this.removeNodes}}
          @onCreateConnection={{this.createConnection}}
          @onAddNodeAtPosition={{this.addNodeAtPosition}}
          @onAddNodeToLoop={{this.addNodeToLoop}}
          @onInsertNodeOnConnection={{this.insertNodeOnConnection}}
          @onConnectionDelete={{this.deleteConnection}}
          @onNodeDragEnd={{this.handleSubmit}}
          @onAreaReady={{this.initializeUndo}}
          @onUndo={{this.undo}}
          @onRedo={{this.redo}}
          @canUndo={{this.canUndo}}
          @canRedo={{this.canRedo}}
          @onAutoLayout={{this.autoLayout}}
          @onHydrateAutoLayout={{this.hydrateAutoLayout}}
          @onSyncAutoLayout={{this.hydrateAutoLayout}}
          @onOpenNodePanel={{this.openNodePanel}}
          @onCloseNodePanel={{this.closeNodePanel}}
          @onImportNodes={{this.importNodes}}
          @onAddStickyNote={{this.addStickyNote}}
          @onStickyNoteBeforeMutation={{this.stickyNoteBeforeMutation}}
          @onStickyNoteMove={{this.stickyNoteMove}}
          @onStickyNoteResize={{this.stickyNoteResize}}
          @onStickyNoteUpdateText={{this.stickyNoteUpdateText}}
          @onStickyNoteChangeColor={{this.stickyNoteChangeColor}}
          @onRemoveSelected={{this.removeSelected}}
          @onPasteEntities={{this.pasteEntities}}
          @workflow={{@workflow}}
          @workflowEnabled={{@workflow.enabled}}
        />

        {{#if this.nodePanelContext}}
          <NodePanel
            @nodeTypes={{this.filteredNodePanelTypes}}
            @searchTerm={{this.nodePanelSearchTerm}}
            @onSearch={{this.searchNodePanel}}
            @onSelectNodeType={{this.selectNodeFromPanel}}
            @onClose={{this.closeNodePanel}}
          />
        {{/if}}
      </div>
    </Form>
  </template>
}
