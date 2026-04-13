import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class WorkflowsNodeTypes extends Service {
  @tracked nodeTypes = null;
  @tracked credentialTypes = null;
  @tracked expressionContext = {};

  // Graph context for the currently-editing node. Set by the editor
  // when the configurator modal opens, read by VariableInput to build
  // CodeMirror completion scope without prop drilling.
  @tracked editingNode = null;
  @tracked graphNodes = null;
  @tracked graphConnections = null;
  @tracked workflowVars = null;
  @tracked workflowId = null;

  _nodeTypeMap = new Map();

  async load() {
    if (this.nodeTypes) {
      return this.nodeTypes;
    }

    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/node-types.json"
      );
      this.nodeTypes = result.node_types || [];
      this.credentialTypes = result.credential_types || [];
      this.expressionContext = result.expression_context || {};
      this._nodeTypeMap = new Map(
        this.nodeTypes.map((nt) => [nt.identifier, nt])
      );
      return this.nodeTypes;
    } catch (e) {
      popupAjaxError(e);
      return [];
    }
  }

  findNodeType(identifier) {
    return this._nodeTypeMap.get(identifier) || null;
  }

  setEditingContext(node, nodes, connections, { workflowId } = {}) {
    this.editingNode = node;
    this.graphNodes = nodes;
    this.graphConnections = connections;
    this.workflowId = workflowId;
  }

  async loadWorkflowVars() {
    if (this.workflowVars) {
      return this.workflowVars;
    }

    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/variables.json"
      );
      this.workflowVars = result.variables || [];
    } catch {
      this.workflowVars = [];
    }
    return this.workflowVars;
  }

  invalidateWorkflowVars() {
    this.workflowVars = null;
  }

  clearEditingContext() {
    this.editingNode = null;
    this.graphNodes = null;
    this.graphConnections = null;
    this.workflowId = null;
  }

  clear() {
    this.nodeTypes = null;
    this.credentialTypes = null;
    this.expressionContext = {};
    this._nodeTypeMap = new Map();
    this.invalidateWorkflowVars();
    this.workflowId = null;
    this.clearEditingContext();
  }
}
