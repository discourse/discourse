import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";

export default class DiscourseWorkflowsWorkflow extends RestModel {
  @tracked name;
  @tracked enabled;
  @tracked last_execution_status;
  @tracked nodes = [];
  @tracked connections = [];

  updateProperties() {
    return {
      name: this.name,
      enabled: this.enabled,
      nodes: this.nodes.map((node) => ({
        client_id: node.client_id,
        type: node.type,
        name: node.name,
        configuration: node.configuration || {},
        position: node.position || null,
      })),
      connections: this.connections.map((conn) => ({
        source_client_id: conn.source_client_id,
        target_client_id: conn.target_client_id,
        source_output: conn.source_output,
      })),
    };
  }

  createProperties() {
    return this.updateProperties();
  }
}
