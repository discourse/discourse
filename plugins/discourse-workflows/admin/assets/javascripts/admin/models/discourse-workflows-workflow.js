import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";
import StickyNote from "./sticky-note";
import WorkflowConnection from "./workflow-connection";
import WorkflowNode from "./workflow-node";

export default class DiscourseWorkflowsWorkflow extends RestModel {
  @tracked name;
  @tracked enabled;
  @tracked error_workflow_id;
  @tracked last_execution_status;
  @tracked nodes = [];
  @tracked connections = [];

  updateProperties() {
    return {
      name: this.name,
      enabled: this.enabled,
      nodes: [
        ...this.nodes.map(WorkflowNode.serialize),
        ...(this.sticky_notes || []).map(StickyNote.serialize),
      ],
      connections: this.connections.map(WorkflowConnection.serialize),
    };
  }

  createProperties() {
    return this.updateProperties();
  }
}
