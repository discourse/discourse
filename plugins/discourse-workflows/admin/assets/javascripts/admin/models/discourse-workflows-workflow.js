import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";
import StickyNote from "./sticky-note";
import { serializeConnections } from "./workflow-connection";
import WorkflowNode from "./workflow-node";

export default class DiscourseWorkflowsWorkflow extends RestModel {
  static munge(json) {
    const result = { ...json };

    if (Object.hasOwn(json, "error_workflow_id")) {
      result.errorWorkflowId = json.error_workflow_id;
    }
    if (Object.hasOwn(json, "error_workflow_name")) {
      result.errorWorkflowName = json.error_workflow_name;
    }
    if (Object.hasOwn(json, "version_id")) {
      result.versionId = json.version_id;
    }
    if (Object.hasOwn(json, "active_version_id")) {
      result.activeVersionId = json.active_version_id;
    }
    if (Object.hasOwn(json, "version_counter")) {
      result.versionCounter = json.version_counter;
    }
    if (Object.hasOwn(json, "has_unpublished_changes")) {
      result.hasUnpublishedChanges = json.has_unpublished_changes;
    }
    if (Object.hasOwn(json, "last_execution_status")) {
      result.lastExecutionStatus = json.last_execution_status;
    }
    if (Object.hasOwn(json, "last_execution_at")) {
      result.lastExecutionAt = json.last_execution_at;
    }
    if (Object.hasOwn(json, "last_execution_run_data")) {
      result.lastExecutionRunData = json.last_execution_run_data;
    }
    if (Object.hasOwn(json, "created_at")) {
      result.createdAt = json.created_at;
    }
    if (Object.hasOwn(json, "updated_at")) {
      result.updatedAt = json.updated_at;
    }
    if (Object.hasOwn(json, "created_by")) {
      result.createdBy = json.created_by;
    }
    if (Object.hasOwn(json, "updated_by")) {
      result.updatedBy = json.updated_by;
    }
    if (Object.hasOwn(json, "static_data")) {
      result.staticData = json.static_data;
    }
    if (Object.hasOwn(json, "pin_data")) {
      result.pinData = json.pin_data;
    }

    return result;
  }

  @tracked name;
  @tracked errorWorkflowId;
  @tracked versionId;
  @tracked activeVersionId;
  @tracked versionCounter;
  @tracked hasUnpublishedChanges;
  @tracked lastExecutionStatus;
  @tracked lastExecutionRunData;
  @tracked timezone;
  @tracked settings;
  @tracked staticData;
  @tracked pinData;
  @tracked nodes = [];
  @tracked connections = [];
  @tracked stickyNotes = [];

  graphProperties() {
    return {
      nodes: [
        ...this.nodes.map(WorkflowNode.serialize),
        ...(this.stickyNotes || []).map(StickyNote.serialize),
      ],
      connections: serializeConnections(this.connections, [
        ...this.nodes,
        ...(this.stickyNotes || []),
      ]),
    };
  }

  createProperties() {
    return {
      name: this.name,
      ...this.graphProperties(),
    };
  }
}
