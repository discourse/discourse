import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  loadNodeTypes,
  nodeTypeLabel,
} from "../../../lib/workflows/node-types";
import StickyNote from "../../../models/sticky-note";
import WorkflowConnection from "../../../models/workflow-connection";
import WorkflowNode from "../../../models/workflow-node";
import WorkflowCanvas from "../canvas";
import NodePanel from "../canvas/node-panel";
import NodeConfigurator from "../node/configurator";
import autoLayout from "./auto-layout";
import { LOOP_NODE_TYPE, removeNodesFromGraph } from "./graph-utils";
import { createNode, generateNodeName } from "./node-factory";
import UndoManager from "./undo-manager";

export default class WorkflowsEditor extends Component {
  @service router;
  @service modal;

  @tracked canUndo = false;
  @tracked canRedo = false;
  @tracked nodePanelContext = null;
  @tracked nodePanelNodeTypes = null;
  @tracked nodePanelSearchTerm = "";
  formApi = null;
  undoManager = new UndoManager();

  formData = {
    name:
      this.args.workflow.name ||
      i18n("discourse_workflows.default_workflow_name"),
    nodes: this.#initNodes(),
    connections: this.#mapServerConnections(),
    stickyNotes: this.#initStickyNotes(),
  };
  _isUndoRedo = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this.undoManager.destroy();
  }

  #mapServerConnections() {
    return (this.args.workflow.connections || []).map(
      WorkflowConnection.create
    );
  }

  #initNodes() {
    const rawNodes = (this.args.workflow.nodes || []).map((node) =>
      WorkflowNode.create({
        ...node,
        position: this.#parsePosition(node.position),
      })
    );

    const connections = this.#mapServerConnections();

    const needsLayout = rawNodes.some((n) => !n.position);
    if (needsLayout && rawNodes.length > 0) {
      return autoLayout(rawNodes, connections);
    }
    return rawNodes;
  }

  #initStickyNotes() {
    return (this.args.workflow.sticky_notes || []).map(StickyNote.create);
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

  ignoreDirty() {
    return false;
  }

  #refreshUndoState() {
    this.canUndo = this.undoManager.canUndo;
    this.canRedo = this.undoManager.canRedo;
  }

  #syncFromServer() {
    const serverNodes = this.args.workflow.nodes || [];
    const formNodes = this.formApi.get("nodes");

    const nodes = serverNodes.map((serverNode, index) => {
      const formNode = formNodes[index];
      return WorkflowNode.create({
        ...serverNode,
        position:
          formNode?.position || this.#parsePosition(serverNode.position),
      });
    });

    this.formApi.set("nodes", nodes);
    this.formApi.set("connections", this.#mapServerConnections());
  }

  #captureGraphSnapshot() {
    return {
      nodes: structuredClone(this.formApi.get("nodes")),
      connections: structuredClone(this.formApi.get("connections")),
      stickyNotes: structuredClone(this.formApi.get("stickyNotes")),
    };
  }

  #captureUndo() {
    this.undoManager.captureBeforeState(this.#captureGraphSnapshot());
  }

  @action
  applySnapshot({ nodes, connections, stickyNotes }) {
    this._isUndoRedo = true;
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
    await this.undoManager.undo();
    this.#refreshUndoState();
  }

  @action
  async redo() {
    await this.undoManager.redo();
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
    const hasSelf = connections.some((connection) =>
      this.#isLoopSelfConnection(connection, clientId)
    );

    if (hasBody && hasSelf) {
      const idx = connections.findIndex((c) =>
        this.#isLoopSelfConnection(c, clientId)
      );
      if (idx >= 0) {
        connections.splice(idx, 1);
      }
    } else if (!hasBody && !hasSelf) {
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

  @action
  addNode(sourceClientId, sourceOutput, nodeType) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const newNode = createNode(nodeType.identifier, existingNodes, null, {
      typeVersion: nodeType.latest_version,
    });

    const nodes = [...existingNodes, newNode];
    this.formApi.set("nodes", nodes);

    const connections = [...this.formApi.get("connections")];
    if (sourceClientId) {
      const existingIdx = connections.findIndex(
        (c) =>
          c.sourceClientId === sourceClientId && c.sourceOutput === sourceOutput
      );

      if (existingIdx >= 0) {
        const existing = connections[existingIdx];
        connections.splice(existingIdx, 1);
        connections.push({
          sourceClientId,
          targetClientId: newNode.clientId,
          sourceOutput,
        });
        const newNodeOutput = nodeType.branching ? "true" : "main";
        connections.push({
          sourceClientId: newNode.clientId,
          targetClientId: existing.targetClientId,
          sourceOutput: newNodeOutput,
        });
      } else {
        connections.push({
          sourceClientId,
          targetClientId: newNode.clientId,
          sourceOutput,
        });
      }
    }

    this.#ensureLoopSelfConnection(
      connections,
      newNode.clientId,
      nodeType.identifier
    );
    this.formApi.set("connections", connections);

    const updatedNodes = autoLayout(
      this.formApi.get("nodes"),
      this.formApi.get("connections")
    );
    this.formApi.set("nodes", updatedNodes);

    this.handleSubmit();
  }

  @action
  addNodeAtPosition(sourceClientId, sourceOutput, nodeType, position) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const newNode = createNode(nodeType.identifier, existingNodes, position, {
      typeVersion: nodeType.latest_version,
    });

    this.formApi.set("nodes", [...existingNodes, newNode]);

    const connections = [...this.formApi.get("connections")];
    if (sourceClientId) {
      connections.push({
        sourceClientId,
        targetClientId: newNode.clientId,
        sourceOutput,
      });
    }

    this.#ensureLoopSelfConnection(
      connections,
      newNode.clientId,
      nodeType.identifier
    );
    this.formApi.set("connections", connections);
    this.handleSubmit();
  }

  @action
  insertNodeOnConnection(
    sourceClientId,
    sourceOutput,
    targetClientId,
    nodeType
  ) {
    this.#captureUndo();
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

    const newNode = createNode(nodeType.identifier, existingNodes, position, {
      typeVersion: nodeType.latest_version,
    });

    this.formApi.set("nodes", [...existingNodes, newNode]);

    const connections = [...this.formApi.get("connections")];

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

    const newNodeOutput = nodeType.branching ? "true" : "main";
    connections.push({
      sourceClientId: newNode.clientId,
      targetClientId,
      sourceOutput: newNodeOutput,
    });

    this.#ensureLoopSelfConnection(
      connections,
      newNode.clientId,
      nodeType.identifier
    );
    this.formApi.set("connections", connections);

    const updatedNodes = autoLayout(
      this.formApi.get("nodes"),
      this.formApi.get("connections")
    );
    this.formApi.set("nodes", updatedNodes);

    this.handleSubmit();
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

    this.modal.show(NodeConfigurator, {
      model: {
        node,
        nodes,
        connections,
        triggerType: triggerNode?.type,
        onSave: (configuration, name) =>
          this.updateNodeConfiguration(clientId, configuration, name),
        onRemove: () => this.removeNode(clientId),
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
  removeNode(clientId) {
    this.removeNodes([clientId]);
  }

  @action
  addNodeToLoop(loopNodeClientId, nodeType) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const loopNode = existingNodes.find((n) => n.clientId === loopNodeClientId);
    const position = loopNode?.position
      ? { x: loopNode.position.x, y: loopNode.position.y + 120 }
      : null;

    const newNode = createNode(nodeType.identifier, existingNodes, position, {
      typeVersion: nodeType.latest_version,
    });
    const newNodeOutput = nodeType.branching ? "true" : "main";

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
    const nodes = this.formApi.get("nodes");
    const updatedNodes = nodes.map((node) => {
      const pos = positions.get(node.clientId);
      return pos ? { ...node, position: pos } : node;
    });
    this.formApi.set("nodes", updatedNodes);
    this.handleSubmit();
  }

  // Sticky notes

  @action
  addStickyNote(position) {
    this.#captureUndo();
    const stickyNotes = [...this.formApi.get("stickyNotes")];
    stickyNotes.push(
      StickyNote.create({
        position: {
          x: position.svgX ?? position.x ?? 0,
          y: position.svgY ?? position.y ?? 0,
        },
      })
    );
    this.formApi.set("stickyNotes", stickyNotes);
    this.handleSubmit();
  }

  @action
  stickyNoteMove(clientId, newPosition) {
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.map((n) =>
        n.clientId === clientId ? { ...n, position: newPosition } : n
      )
    );
  }

  @action
  stickyNoteResize(clientId, newSize) {
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.map((n) =>
        n.clientId === clientId ? { ...n, size: newSize } : n
      )
    );
  }

  @action
  stickyNoteUpdateText(clientId, text) {
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.map((n) => (n.clientId === clientId ? { ...n, text } : n))
    );
  }

  @action
  stickyNoteDragStart() {
    this.#captureUndo();
  }

  @action
  stickyNoteChangeColor(clientId, color) {
    this.#captureUndo();
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.map((n) => (n.clientId === clientId ? { ...n, color } : n))
    );
  }

  @action
  pasteStickyNote(copiedNote) {
    this.#captureUndo();
    const offset = 20;
    const position = {
      x: (copiedNote.position?.x ?? 0) + offset,
      y: (copiedNote.position?.y ?? 0) + offset,
    };
    const note = StickyNote.create({
      position,
      size: copiedNote.size,
      color: copiedNote.color,
      text: copiedNote.text,
    });
    const stickyNotes = [...this.formApi.get("stickyNotes"), note];
    this.formApi.set("stickyNotes", stickyNotes);
    this.handleSubmit();
    return { clientId: note.clientId, position };
  }

  @action
  pasteNode(copiedNode) {
    this.#captureUndo();
    const offset = 20;
    const existingNodes = this.formApi.get("nodes");
    const position = copiedNode.position
      ? {
          x: copiedNode.position.x + offset,
          y: copiedNode.position.y + offset,
        }
      : null;

    const newNode = WorkflowNode.create({
      type: copiedNode.type,
      type_version: copiedNode.type_version,
      name: generateNodeName(copiedNode.type, existingNodes),
      configuration: structuredClone(copiedNode.configuration || {}),
      position,
    });

    this.formApi.set("nodes", [...existingNodes, newNode]);
    this.handleSubmit();
    return position;
  }

  @action
  stickyNoteDelete(clientId) {
    this.#captureUndo();
    const stickyNotes = this.formApi.get("stickyNotes");
    this.formApi.set(
      "stickyNotes",
      stickyNotes.filter((n) => n.clientId !== clientId)
    );
    this.handleSubmit();
  }

  @action
  async openNodePanel(context) {
    if (!this.nodePanelNodeTypes) {
      this.nodePanelNodeTypes = await loadNodeTypes();
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
  selectNodeFromPanel(nodeType) {
    const ctx = this.nodePanelContext;
    if (!ctx) {
      return;
    }

    if (ctx.loopNodeClientId) {
      this.addNodeToLoop(ctx.loopNodeClientId, nodeType);
    } else if (ctx.connectionSource) {
      this.insertNodeOnConnection(
        ctx.connectionSource,
        ctx.connectionSourceOutput,
        ctx.connectionTarget,
        nodeType
      );
    } else if (ctx.svgX != null) {
      this.addNodeAtPosition(null, "main", nodeType, {
        x: ctx.svgX,
        y: ctx.svgY,
      });
    } else {
      this.addNode(null, "main", nodeType);
    }

    this.closeNodePanel();
  }

  @action
  async handleSubmit() {
    if (this._saving) {
      this._pendingSave = true;
      return;
    }

    this._saving = true;
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

      if (!this._isUndoRedo) {
        this.undoManager.commitAction(this.#captureGraphSnapshot());
      }
      this._isUndoRedo = false;
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
      this._saving = false;
      if (this._pendingSave) {
        this._pendingSave = false;
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
          @onUpdateNodePosition={{this.updateNodePosition}}
          @onEditNode={{this.editNode}}
          @onRemoveNode={{this.removeNode}}
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
          @onOpenNodePanel={{this.openNodePanel}}
          @onCloseNodePanel={{this.closeNodePanel}}
          @onImportNodes={{this.importNodes}}
          @onAddStickyNote={{this.addStickyNote}}
          @onStickyNoteDragStart={{this.stickyNoteDragStart}}
          @onStickyNoteMove={{this.stickyNoteMove}}
          @onStickyNoteResize={{this.stickyNoteResize}}
          @onStickyNoteUpdateText={{this.stickyNoteUpdateText}}
          @onStickyNoteChangeColor={{this.stickyNoteChangeColor}}
          @onStickyNoteDelete={{this.stickyNoteDelete}}
          @onPasteStickyNote={{this.pasteStickyNote}}
          @onPasteNode={{this.pasteNode}}
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
