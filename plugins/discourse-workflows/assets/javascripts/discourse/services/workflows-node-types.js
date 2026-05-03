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
  @tracked lastExecutionNodeOutputs = null;

  nodeTypeMap = new Map();
  _sourceOptionsCache = new Map();

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
      this.nodeTypeMap = new Map(
        this.nodeTypes.map((nt) => [nt.identifier, nt])
      );
      return this.nodeTypes;
    } catch (e) {
      popupAjaxError(e);
      return [];
    }
  }

  findNodeType(identifier) {
    return this.nodeTypeMap.get(identifier) || null;
  }

  async loadSourceOptions(identifier, sourceKey) {
    const cacheKey = `${identifier}:${sourceKey}`;
    if (this._sourceOptionsCache.has(cacheKey)) {
      return this._sourceOptionsCache.get(cacheKey);
    }

    try {
      const encodedIdentifier = encodeURIComponent(identifier);
      const result = await ajax(
        `/admin/plugins/discourse-workflows/node-types/${encodedIdentifier}/options/${sourceKey}.json`
      );
      const options = result.options || [];
      this._sourceOptionsCache.set(cacheKey, options);
      return options;
    } catch (e) {
      popupAjaxError(e);
      return [];
    }
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
    this.lastExecutionNodeOutputs = null;
  }

  clear() {
    this.nodeTypes = null;
    this.credentialTypes = null;
    this.expressionContext = {};
    this.nodeTypeMap = new Map();
    this._sourceOptionsCache = new Map();
    this.invalidateWorkflowVars();
    this.workflowId = null;
    this.lastExecutionNodeOutputs = null;
    this.clearEditingContext();
  }
}
