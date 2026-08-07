import { module, test } from "qunit";
import DiscourseWorkflowsWorkflow from "discourse/plugins/discourse-workflows/admin/models/discourse-workflows-workflow";

module("Unit | model | discourse-workflows-workflow", function () {
  test("munge maps API snake_case fields to model camelCase fields", function (assert) {
    const payload = DiscourseWorkflowsWorkflow.munge({
      id: "1",
      error_workflow_id: 2,
      error_workflow_name: "Error handler",
      version_id: "draft-version",
      active_version_id: "published-version",
      version_counter: 3,
      has_unpublished_changes: true,
      last_execution_status: "success",
      last_execution_at: "2026-05-27T10:00:00.000Z",
      last_execution_run_data: { "Node A": [{ json: { ok: true } }] },
      created_at: "2026-05-26T10:00:00.000Z",
      updated_at: "2026-05-27T10:00:00.000Z",
      created_by: { id: 1, username: "admin" },
      updated_by: { id: 2, username: "moderator" },
      static_data: { global: { cursor: "abc" } },
      pin_data: { "Node A": [{ json: { ok: true } }] },
    });

    assert.strictEqual(payload.errorWorkflowId, 2);
    assert.strictEqual(payload.errorWorkflowName, "Error handler");
    assert.strictEqual(payload.versionId, "draft-version");
    assert.strictEqual(payload.activeVersionId, "published-version");
    assert.strictEqual(payload.versionCounter, 3);
    assert.true(payload.hasUnpublishedChanges);
    assert.strictEqual(payload.lastExecutionStatus, "success");
    assert.strictEqual(payload.lastExecutionAt, "2026-05-27T10:00:00.000Z");
    assert.deepEqual(payload.lastExecutionRunData, {
      "Node A": [{ json: { ok: true } }],
    });
    assert.strictEqual(payload.createdAt, "2026-05-26T10:00:00.000Z");
    assert.strictEqual(payload.updatedAt, "2026-05-27T10:00:00.000Z");
    assert.deepEqual(payload.createdBy, { id: 1, username: "admin" });
    assert.deepEqual(payload.updatedBy, { id: 2, username: "moderator" });
    assert.deepEqual(payload.staticData, { global: { cursor: "abc" } });
    assert.deepEqual(payload.pinData, {
      "Node A": [{ json: { ok: true } }],
    });
  });

  test("createProperties maps model fields to API snake_case fields", function (assert) {
    const workflow = DiscourseWorkflowsWorkflow.create({
      name: "Workflow",
      nodes: [],
      stickyNotes: [],
      connections: [],
    });

    assert.deepEqual(workflow.createProperties(), {
      name: "Workflow",
      nodes: [],
      connections: {},
    });
  });
});
