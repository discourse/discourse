import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import WorkflowEditorSession from "../../../lib/workflows/editor-session";
import {
  connectionMatchesEndpoint,
  nextAvailableTargetInputIndex,
  normalizeSourceOutputIndex,
  portIndexFromKey,
} from "../../../lib/workflows/graph-constants";
import {
  nodeTypeInputUsesConnectionIndexes,
  nodeTypeLabel,
  nodeTypeOutputKeys,
  nodeTypePrimaryOutputKey,
  nodeTypeVersion,
  resolveNodeTypeVersion,
} from "../../../lib/workflows/node-types";
import { mergeImportedStaticData } from "../../../lib/workflows/static-data";
import StickyNote, { STICKY_NOTE_TYPE } from "../../../models/sticky-note";
import { deserializeConnections } from "../../../models/workflow-connection";
import WorkflowNode from "../../../models/workflow-node";
import WorkflowCanvas from "../canvas";
import NodePanel from "../canvas/node-panel";
import NodeConfigurator from "../node/configurator";
import {
  LOOP_NODE_TYPE,
  normalizeConnectionsForNodes,
  normalizeNodeConfiguration,
  removeNodesFromGraph,
} from "./graph-utils";
import { createNode, generateNodeName } from "./node-factory";
import UndoManager from "./undo-manager";

const MAX_NODES = 50;

function nodeTypeIdentifier(nodeType) {
  return nodeType?.name || nodeType?.identifier || nodeType?.type || "";
}

function isTriggerType(type) {
  return type?.startsWith("trigger:");
}

export function isNodeUnavailable(workflowsNodeTypes, node) {
  const nodeType = workflowsNodeTypes.findNodeType(node.type);
  if (!nodeType) {
    return true;
  }

  return (
    resolveNodeTypeVersion(nodeType, node.typeVersion)?.available === false
  );
}

function shouldHideTriggerNodeTypes(context, nodes) {
  const sourceClientId = context?.sourceClientId || context?.connectionSource;

  if (!sourceClientId) {
    return false;
  }

  const sourceNode = nodes?.find((node) => node.clientId === sourceClientId);

  return isTriggerType(sourceNode?.type);
}

export default class WorkflowsEditor extends Component {
  @service router;
  @service dialog;
  @service modal;
  @service toasts;
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
  allowUnpublishedDraftTransition = false;
  currentSavePromise = null;
  pendingGraphSnapshot = null;
  pendingSaveOptions = null;
  workflowSession = new WorkflowEditorSession({
    workflowId: this.args.workflow?.id,
    lastExecutionRunData: this.args.workflow?.lastExecutionRunData || null,
    pinData: this.args.workflow?.pinData || {},
  });

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
    this.#subscribeToExecutions();
    this.router.on("routeWillChange", this.confirmUnpublishedDraftTransition);
    window.addEventListener("beforeunload", this.handleBeforeUnload);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.undoManager.destroy();
    this.#unsubscribeFromExecutions();
    this.router.off("routeWillChange", this.confirmUnpublishedDraftTransition);
    window.removeEventListener("beforeunload", this.handleBeforeUnload);
  }

  get hasUnpublishedDraft() {
    return Boolean(
      (this.args.workflow?.activeVersionId &&
        this.args.workflow?.hasUnpublishedChanges) ||
      this.saving ||
      this.pendingSave
    );
  }

  @bind
  handleBeforeUnload(event) {
    if (!this.hasUnpublishedDraft) {
      return;
    }

    const message = i18n(
      "discourse_workflows.unpublished_changes_confirmation"
    );
    event.preventDefault();
    event.returnValue = message;
    return message;
  }

  @bind
  confirmUnpublishedDraftTransition(transition) {
    const routeChanging = transition.to?.name !== transition.from?.name;
    const shouldCheck =
      this.hasUnpublishedDraft &&
      !this.allowUnpublishedDraftTransition &&
      !transition.isAborted &&
      (!transition.queryParamsOnly || routeChanging);

    if (!shouldCheck) {
      return;
    }

    transition.abort();

    this.dialog.dialog({
      class: "workflows-unpublished-draft-dialog",
      message: i18n("discourse_workflows.unpublished_changes_confirmation"),
      type: "confirm",
      buttons: [
        {
          label: i18n("discourse_workflows.leave_without_publishing"),
          class: "btn-primary",
          action: () => this.leaveWithoutPublishing(transition),
        },
        {
          label: i18n("discourse_workflows.keep_editing"),
          class: "btn-default",
        },
        {
          label: i18n("discourse_workflows.discard_changes"),
          class: "btn-default workflows-unpublished-draft-dialog__discard-btn",
          action: () => this.discardDraftAndRetryTransition(transition),
        },
      ],
    });
  }

  @action
  leaveWithoutPublishing(transition) {
    this.allowUnpublishedDraftTransition = true;
    transition.retry();
  }

  @action
  async discardDraftAndRetryTransition(transition) {
    const confirmed = await this.confirmDiscardChanges();

    if (!confirmed) {
      return;
    }

    await this.discardWorkflowDraft();
    this.leaveWithoutPublishing(transition);
  }

  confirmDiscardChanges() {
    return this.dialog.confirm({
      message: i18n("discourse_workflows.discard_changes_confirmation"),
      confirmButtonLabel: "discourse_workflows.discard_changes",
      cancelButtonLabel: "discourse_workflows.keep_editing",
    });
  }

  #subscribeToExecutions() {
    const workflowId = this.args.workflow?.id;
    if (!workflowId) {
      return;
    }
    this.executionChannel = `/discourse-workflows/workflow/${workflowId}`;
    this.messageBus.subscribe(this.executionChannel, (message) => {
      if (message.type === "execution_completed") {
        this.workflowSession.lastExecutionRunData =
          message.lastExecutionRunData;
        const completedNodeIds = Object.keys(
          message.lastExecutionRunData || {}
        );
        if (message.execution?.trigger_node_id) {
          completedNodeIds.push(message.execution.trigger_node_id);
        }
        const completedWebhookTest = completedNodeIds.some((nodeId) =>
          this.workflowSession.webhookTestListenerForNode(nodeId)
        );

        for (const nodeId of completedNodeIds) {
          this.workflowSession.clearWebhookTestListener(nodeId);
        }

        if (completedWebhookTest && message.execution) {
          const toastType =
            message.execution.status === "error" ? "error" : "success";
          this.toasts[toastType]({
            data: {
              message:
                message.execution.status === "error"
                  ? i18n("discourse_workflows.manual_trigger.failed")
                  : i18n("discourse_workflows.manual_trigger.triggered"),
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
                      message.execution.workflow_id,
                      message.execution.id
                    );
                  },
                },
              ],
            },
          });
        }
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
    const nodes = this.#initNodes();
    return normalizeConnectionsForNodes(
      deserializeConnections(this.args.workflow.connections || {}, nodes),
      nodes,
      (node) => this.#nodeTypeFor(node)
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

  #applyGraphSnapshot({ nodes, connections, stickyNotes }) {
    this.formApi.set("nodes", nodes);
    this.formApi.set("connections", connections);
    if (stickyNotes) {
      this.formApi.set("stickyNotes", stickyNotes);
    }
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
    this.#applyGraphSnapshot({ nodes, connections, stickyNotes });
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

  @action
  browseTemplates() {
    const nodes = this.formApi.get("nodes") || [];
    const stickyNotes = this.formApi.get("stickyNotes") || [];

    if (nodes.length === 0 && stickyNotes.length === 0) {
      this.allowUnpublishedDraftTransition = true;
    }

    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows-templates",
      {
        queryParams: { workflow_id: this.args.workflow.id },
      }
    );
  }

  async #undoRedoAction(method) {
    await this.undoManager[method]();
    this.#refreshUndoState();
  }

  #isLoopSelfConnection(connection, clientId) {
    return (
      connection.sourceClientId === clientId &&
      connection.targetClientId === clientId &&
      this.#isLoopOutputConnection(connection, clientId)
    );
  }

  #isLoopOutputConnection(connection, loopNodeClientId) {
    return (
      connection.sourceClientId === loopNodeClientId &&
      (connection.sourceOutput === "loop" ||
        normalizeSourceOutputIndex(connection) === 1)
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
        this.#isLoopOutputConnection(connection, loopNodeClientId) &&
        connection.targetClientId !== loopNodeClientId
    );
  }

  #sourceOutputIndexFor(
    sourceClientId,
    sourceOutput,
    nodes = this.formApi.get("nodes")
  ) {
    const sourceNode = nodes?.find((node) => node.clientId === sourceClientId);

    return portIndexFromKey(
      sourceOutput,
      nodeTypeOutputKeys(this.#nodeTypeFor(sourceNode), sourceNode)
    );
  }

  #nodeTypeFor(node) {
    return this.workflowsNodeTypes.findNodeType(node?.type) || node?.type;
  }

  #targetInputIndexFor(
    targetClientId,
    targetInput,
    nodes = this.formApi.get("nodes"),
    connections = this.formApi.get("connections")
  ) {
    const targetNode = nodes?.find((node) => node.clientId === targetClientId);

    if (
      !nodeTypeInputUsesConnectionIndexes(
        this.#nodeTypeFor(targetNode),
        targetInput,
        targetNode
      )
    ) {
      return portIndexFromKey(targetInput);
    }

    return nextAvailableTargetInputIndex(connections, targetClientId);
  }

  #addNewNode(nodeType, position, configOverrides, wireConnections) {
    const existingNodes = this.formApi.get("nodes");
    if (existingNodes.length >= MAX_NODES) {
      this.toasts.error({
        data: {
          message: i18n("discourse_workflows.canvas.max_nodes_reached", {
            max: MAX_NODES,
          }),
        },
      });
      return;
    }
    this.#captureUndo();
    const newNode = createNode(
      nodeType.name || nodeType.identifier,
      existingNodes,
      position,
      {
        typeVersion: nodeTypeVersion(nodeType),
        configOverrides,
      }
    );

    this.formApi.set("nodes", [...existingNodes, newNode]);

    const connections = [...this.formApi.get("connections")];
    const shouldAutoLayout = wireConnections(connections, newNode, nodeType);

    this.#ensureLoopSelfConnection(
      connections,
      newNode.clientId,
      nodeType.name || nodeType.identifier
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
          const sourceOutputIndex = this.#sourceOutputIndexFor(
            sourceClientId,
            sourceOutput
          );
          const existingIdx = connections.findIndex(
            (connection) =>
              connection.sourceClientId === sourceClientId &&
              normalizeSourceOutputIndex(connection) === sourceOutputIndex
          );

          if (existingIdx >= 0) {
            const existing = connections[existingIdx];
            connections.splice(existingIdx, 1);
            connections.push({
              sourceClientId,
              targetClientId: newNode.clientId,
              sourceOutput,
              sourceOutputIndex,
            });
            connections.push({
              sourceClientId: newNode.clientId,
              targetClientId: existing.targetClientId,
              sourceOutput: nodeTypePrimaryOutputKey(nodeType),
              targetInput: existing.targetInput,
              targetInputIndex: existing.targetInputIndex,
            });
          } else {
            connections.push({
              sourceClientId,
              targetClientId: newNode.clientId,
              sourceOutput,
              sourceOutputIndex,
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
            sourceOutputIndex: this.#sourceOutputIndexFor(
              sourceClientId,
              sourceOutput
            ),
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
    configOverrides = null,
    targetInput = "main",
    sourceOutputIndex = null,
    targetInputIndex = null
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
        const existingIdx = connections.findIndex((connection) =>
          connectionMatchesEndpoint(connection, {
            sourceClientId,
            sourceOutput,
            sourceOutputIndex,
            targetClientId,
            targetInput,
            targetInputIndex,
          })
        );
        if (existingIdx >= 0) {
          connections.splice(existingIdx, 1);
        }

        connections.push({
          sourceClientId,
          targetClientId: newNode.clientId,
          sourceOutput,
          sourceOutputIndex:
            sourceOutputIndex ??
            this.#sourceOutputIndexFor(
              sourceClientId,
              sourceOutput,
              existingNodes
            ),
          targetInput: "main",
        });
        connections.push({
          sourceClientId: newNode.clientId,
          targetClientId,
          sourceOutput: nodeTypePrimaryOutputKey(nodeType),
          targetInput,
          targetInputIndex,
        });
        return true;
      }
    );
  }

  @action
  addNodeBeforeTarget(
    targetClientId,
    nodeType,
    configOverrides = null,
    targetInput = "main"
  ) {
    const targetNode = this.formApi
      .get("nodes")
      .find((n) => n.clientId === targetClientId);
    const position = targetNode?.position
      ? { x: targetNode.position.x - 200, y: targetNode.position.y }
      : null;

    this.#addNewNode(
      nodeType,
      position,
      configOverrides,
      (connections, newNode, nt) => {
        connections.push({
          sourceClientId: newNode.clientId,
          targetClientId,
          sourceOutput: nodeTypePrimaryOutputKey(nt),
          targetInput,
        });
        return !position;
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

    if (isNodeUnavailable(this.workflowsNodeTypes, node)) {
      return;
    }

    const triggerNode = nodes.find((n) => n.type?.startsWith("trigger:"));

    this.workflowSession.setEditingContext(node, nodes, connections);

    this.modal.show(NodeConfigurator, {
      model: {
        node,
        nodes,
        connections,
        session: this.workflowSession,
        triggerType: triggerNode?.type,
        onSave: (configuration, name, options) =>
          this.updateNodeConfiguration(clientId, configuration, name, options),
        onRemove: () => this.removeNodes([clientId]),
      },
    });
  }

  @action
  createConnection(
    sourceClientId,
    sourceOutput,
    targetClientId,
    targetInput = "main",
    sourceOutputIndex = null,
    targetInputIndex = null
  ) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    const connections = [...this.formApi.get("connections")];
    sourceOutputIndex ??= this.#sourceOutputIndexFor(
      sourceClientId,
      sourceOutput,
      nodes
    );
    targetInputIndex ??= this.#targetInputIndexFor(
      targetClientId,
      targetInput,
      nodes,
      connections
    );

    // Don't create duplicate connections
    const exists = connections.some((connection) =>
      connectionMatchesEndpoint(connection, {
        sourceClientId,
        sourceOutput,
        sourceOutputIndex,
        targetClientId,
        targetInput,
        targetInputIndex,
      })
    );
    if (exists) {
      return;
    }

    connections.push({
      sourceClientId,
      targetClientId,
      sourceOutput,
      sourceOutputIndex,
      targetInput,
      targetInputIndex,
    });
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
  deleteConnection(
    sourceClientId,
    sourceOutput,
    targetClientId,
    targetInput = "main",
    sourceOutputIndex = null,
    targetInputIndex = null
  ) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    const connections = [...this.formApi.get("connections")];
    sourceOutputIndex ??= this.#sourceOutputIndexFor(
      sourceClientId,
      sourceOutput,
      nodes
    );
    const index = connections.findIndex((connection) =>
      connectionMatchesEndpoint(connection, {
        sourceClientId,
        sourceOutput,
        sourceOutputIndex,
        targetClientId,
        targetInput,
        targetInputIndex,
      })
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
    const existingNodes = this.formApi.get("nodes");
    if (existingNodes.length >= MAX_NODES) {
      this.toasts.error({
        data: {
          message: i18n("discourse_workflows.canvas.max_nodes_reached", {
            max: MAX_NODES,
          }),
        },
      });
      return;
    }
    this.#captureUndo();
    const loopNode = existingNodes.find((n) => n.clientId === loopNodeClientId);
    const position = loopNode?.position
      ? { x: loopNode.position.x, y: loopNode.position.y + 120 }
      : null;

    const newNode = createNode(
      nodeType.name || nodeType.identifier,
      existingNodes,
      position,
      {
        typeVersion: nodeTypeVersion(nodeType),
        configOverrides,
      }
    );
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
          this.#isLoopOutputConnection(c, loopNodeClientId) &&
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
  updateNodeConfiguration(clientId, configuration, name, options = {}) {
    this.#captureUndo();
    const nodes = this.formApi.get("nodes");
    const updatedNodes = nodes.map((n) =>
      n.clientId === clientId
        ? normalizeNodeConfiguration(
            {
              ...n,
              configuration,
              name: name || n.name,
            },
            this.#nodeTypeFor(n)
          )
        : n
    );
    this.formApi.set("nodes", updatedNodes);
    this.formApi.set(
      "connections",
      normalizeConnectionsForNodes(
        this.formApi.get("connections"),
        updatedNodes,
        (node) => this.#nodeTypeFor(node)
      )
    );
    return this.handleSubmit(options);
  }

  @action
  replaceTrigger(clientId, nodeType) {
    this.#captureUndo();
    const existingNodes = this.formApi.get("nodes");
    const replacement = createNode(
      nodeType.name || nodeType.identifier,
      existingNodes,
      null,
      {
        typeVersion: nodeTypeVersion(nodeType),
      }
    );

    const nodes = existingNodes.map((n) =>
      n.clientId === clientId
        ? {
            ...n,
            type: replacement.type,
            typeVersion: replacement.typeVersion,
            name: replacement.name,
            configuration: replacement.configuration,
          }
        : n
    );

    this.formApi.set("nodes", nodes);
    this.handleSubmit();
  }

  @action
  importNodes(newNodes, newConnections, newStickyNotes, staticData) {
    const existingNodes = this.formApi.get("nodes");
    if (existingNodes.length + newNodes.length > MAX_NODES) {
      this.toasts.error({
        data: {
          message: i18n("discourse_workflows.canvas.max_nodes_reached", {
            max: MAX_NODES,
          }),
        },
      });
      return;
    }
    this.#captureUndo();
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

    const saveOptions = {};
    if (staticData !== undefined) {
      saveOptions.staticData = mergeImportedStaticData(
        this.pendingSaveOptions?.staticData || this.args.workflow.staticData,
        staticData
      );
    }

    this.handleSubmit(saveOptions);
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

    if (nodes.length > 0) {
      const existingNodes = this.formApi.get("nodes");
      const newNodes = nodes.map((copiedNode) =>
        WorkflowNode.create({
          type: copiedNode.type,
          typeVersion: copiedNode.typeVersion,
          name: generateNodeName(copiedNode.type, existingNodes),
          configuration: structuredClone(copiedNode.configuration || {}),
          position: copiedNode.position
            ? { x: copiedNode.position.x, y: copiedNode.position.y }
            : null,
        })
      );
      this.formApi.set("nodes", [...existingNodes, ...newNodes]);
    }

    if (stickyNotes.length > 0) {
      const newNotes = stickyNotes.map((copiedNote) =>
        StickyNote.create({
          position: {
            x: copiedNote.position?.x ?? 0,
            y: copiedNote.position?.y ?? 0,
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
    const nodeTypes = shouldHideTriggerNodeTypes(
      this.nodePanelContext,
      this.formApi?.get("nodes")
    )
      ? this.nodePanelNodeTypes.filter(
          (nodeType) => !isTriggerType(nodeTypeIdentifier(nodeType))
        )
      : this.nodePanelNodeTypes;

    if (!term) {
      return nodeTypes;
    }
    return nodeTypes.filter((nt) => {
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
    } else if (ctx.targetClientId) {
      this.addNodeBeforeTarget(
        ctx.targetClientId,
        nodeType,
        configOverrides,
        ctx.targetInput
      );
    } else if (ctx.connectionSource) {
      this.insertNodeOnConnection(
        ctx.connectionSource,
        ctx.connectionSourceOutput,
        ctx.connectionTarget,
        nodeType,
        configOverrides,
        ctx.connectionTargetInput,
        ctx.connectionSourceOutputIndex,
        ctx.connectionTargetInputIndex
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
  async handleSubmit(options = {}) {
    if (this.saving) {
      if (options.throwOnError) {
        await this.currentSavePromise;
        return this.handleSubmit(options);
      } else {
        this.pendingSave = true;
        this.pendingGraphSnapshot = this.#captureGraphSnapshot();
        this.pendingSaveOptions = this.#mergePendingSaveOptions(
          this.pendingSaveOptions,
          options
        );
      }
      return;
    }

    const savePromise = this.#saveWorkflow(options);
    this.currentSavePromise = savePromise;
    try {
      await savePromise;
    } finally {
      if (this.currentSavePromise === savePromise) {
        this.currentSavePromise = null;
      }
    }
  }

  @action
  replaceWorkflow(workflow) {
    this.pendingSave = false;
    this.pendingGraphSnapshot = null;
    this.pendingSaveOptions = null;

    this.args.workflow.setProperties({
      name: workflow.name,
      nodes: workflow.nodes || [],
      connections: workflow.connections || {},
      versionId: workflow.version_id,
      activeVersionId: workflow.active_version_id,
      versionCounter: workflow.version_counter,
      hasUnpublishedChanges: workflow.has_unpublished_changes,
      settings: workflow.settings || {},
      timezone: workflow.timezone,
      staticData: workflow.static_data || {},
      pinData: workflow.pin_data || {},
    });

    this.formApi.set("name", workflow.name);
    this.#syncFromServer();
    this.closeNodePanel();
    this.undoManager.clear();
    this.#refreshUndoState();
  }

  async discardWorkflowDraft() {
    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/discard-draft.json`,
        {
          type: "POST",
        }
      );

      this.replaceWorkflow(response.workflow);
    } catch (e) {
      popupAjaxError(e);
      throw e;
    }
  }

  async #saveWorkflow(options = {}) {
    this.saving = true;
    try {
      const nodes = this.formApi.get("nodes");
      const connections = normalizeConnectionsForNodes(
        this.formApi.get("connections"),
        nodes,
        (node) => this.#nodeTypeFor(node)
      );
      const stickyNotes = this.formApi.get("stickyNotes");
      this.formApi.set("connections", connections);

      const workflowProperties = {
        nodes,
        connections,
        stickyNotes: stickyNotes || [],
      };

      if (this.args.isNew) {
        workflowProperties.name = this.formApi.get("name");
      }

      this.args.workflow.setProperties(workflowProperties);

      const saveProperties = this.args.isNew
        ? this.args.workflow.createProperties()
        : this.args.workflow.graphProperties();
      if (options.staticData !== undefined) {
        saveProperties.static_data = options.staticData;
      }

      await this.args.workflow.save(saveProperties);
      this.#syncFromServer();

      if (!this.isUndoRedo) {
        this.undoManager.commitAction(this.#captureGraphSnapshot());
      }
      this.isUndoRedo = false;
      this.#refreshUndoState();

      if (this.args.isNew) {
        this.allowUnpublishedDraftTransition = true;
        this.router.transitionTo(
          "adminPlugins.show.discourse-workflows.show",
          this.args.workflow.id
        );
      }
    } catch (e) {
      popupAjaxError(e);
      if (options.throwOnError) {
        throw e;
      }
    } finally {
      this.saving = false;
      if (this.pendingSave) {
        const pendingSnapshot = this.pendingGraphSnapshot;
        const pendingOptions = this.pendingSaveOptions || {};
        if (
          options.staticData !== undefined &&
          pendingOptions.staticData !== undefined
        ) {
          pendingOptions.staticData = mergeImportedStaticData(
            options.staticData,
            pendingOptions.staticData
          );
        }
        this.pendingSave = false;
        this.pendingGraphSnapshot = null;
        this.pendingSaveOptions = null;
        if (pendingSnapshot) {
          this.#applyGraphSnapshot(pendingSnapshot);
        }
        this.handleSubmit(pendingOptions);
      }
    }
  }

  #mergePendingSaveOptions(existingOptions, nextOptions) {
    if (nextOptions.staticData === undefined) {
      return existingOptions || {};
    }

    return {
      ...(existingOptions || {}),
      staticData:
        existingOptions?.staticData === undefined
          ? nextOptions.staticData
          : mergeImportedStaticData(
              existingOptions.staticData,
              nextOptions.staticData
            ),
    };
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
          @onBrowseTemplates={{this.browseTemplates}}
          @onDiscardWorkflow={{this.replaceWorkflow}}
          @onWorkflowUpdated={{this.replaceWorkflow}}
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
          @session={{this.workflowSession}}
          @workflowPublished={{@workflow.activeVersionId}}
          @hasUnpublishedChanges={{@workflow.hasUnpublishedChanges}}
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
