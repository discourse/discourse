import { module, test } from "qunit";
import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows";

module("Unit | Component | workflows index", function () {
  test("status label calls out published workflows with draft changes", function (assert) {
    const component = Object.create(WorkflowsIndex.prototype);
    const workflow = {
      activeVersionId: 1,
      hasUnpublishedChanges: true,
    };

    assert.strictEqual(
      component.workflowStatusLabel(workflow),
      "discourse_workflows.unpublished_changes"
    );
    assert.strictEqual(
      component.workflowStatusClass(workflow),
      "is-unpublished-changes"
    );
  });

  test("tag helpers derive names, selection, and search results", async function (assert) {
    const component = Object.create(WorkflowsIndex.prototype);
    component.args = {
      workflowTags: [
        { id: 1, name: "billing", workflow_count: 1 },
        { id: 2, name: "ops", workflow_count: 2 },
      ],
    };
    component.tagFilter = ["ops"];

    assert.deepEqual(component.availableTagNames, ["billing", "ops"]);
    assert.deepEqual(component.tagSelection, [
      { id: 2, name: "ops", workflow_count: 2 },
    ]);
    assert.true(component.hasActiveFilters);

    assert.deepEqual(await component.loadTags("bil"), [
      { id: 1, name: "billing", workflow_count: 1 },
    ]);
    assert.strictEqual((await component.loadTags("")).length, 2);

    component.tagFilter = [];
    assert.false(component.hasActiveFilters);
  });

  test("normalizeTagFilter downcases and drops unknown tags", function (assert) {
    const component = Object.create(WorkflowsIndex.prototype);
    component.args = {
      workflowTags: [
        { id: 1, name: "billing", workflow_count: 1 },
        { id: 2, name: "ops", workflow_count: 2 },
      ],
    };

    assert.deepEqual(component.normalizeTagFilter("OPS, Billing, missing"), [
      "ops",
      "billing",
    ]);
    assert.deepEqual(component.normalizeTagFilter("  Ops  "), ["ops"]);
    assert.deepEqual(component.normalizeTagFilter(""), []);
  });

  test("status label keeps published and unpublished states distinct", function (assert) {
    const component = Object.create(WorkflowsIndex.prototype);

    assert.strictEqual(
      component.workflowStatusLabel({ activeVersionId: 1 }),
      "discourse_workflows.published"
    );
    assert.strictEqual(
      component.workflowStatusClass({ activeVersionId: 1 }),
      "is-published"
    );
    assert.strictEqual(
      component.workflowStatusLabel({ activeVersionId: null }),
      "discourse_workflows.unpublished"
    );
    assert.strictEqual(
      component.workflowStatusClass({ activeVersionId: null }),
      "is-unpublished"
    );
  });
});
