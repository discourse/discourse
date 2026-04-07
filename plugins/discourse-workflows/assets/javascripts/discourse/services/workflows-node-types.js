import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class WorkflowsNodeTypes extends Service {
  @tracked nodeTypes = null;
  @tracked credentialTypes = null;
  @tracked expressionContext = {};

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

  clear() {
    this.nodeTypes = null;
    this.credentialTypes = null;
    this.expressionContext = {};
    this._nodeTypeMap = new Map();
  }
}
