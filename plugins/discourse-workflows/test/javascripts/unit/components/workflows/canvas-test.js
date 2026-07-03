import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import WorkflowCanvas from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas";

module("Unit | Component | workflows canvas", function (hooks) {
  setupTest(hooks);

  test("autoLayout is defined on the prototype", function (assert) {
    assert.true(
      "autoLayout" in WorkflowCanvas.prototype,
      "autoLayout action exists"
    );
  });

  test("sync lifecycle entrypoints are defined on the prototype", function (assert) {
    assert.true(
      "registerCanvas" in WorkflowCanvas.prototype,
      "registerCanvas action exists"
    );
    assert.true(
      "registerContainer" in WorkflowCanvas.prototype,
      "registerContainer action exists"
    );
    assert.true(
      "syncToRete" in WorkflowCanvas.prototype,
      "syncToRete action exists"
    );
  });

  test("browseTemplates delegates to the editor", function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);

    Object.defineProperty(canvas, "args", {
      value: {
        onBrowseTemplates() {
          assert.step("browse");
        },
      },
    });

    canvas.browseTemplates();

    assert.verifySteps(["browse"]);
  });

  test("publish success clears optimistic unpublished changes override", async function (assert) {
    pretender.put("/admin/plugins/discourse-workflows/workflows/1.json", () =>
      response({})
    );

    const workflow = {
      versionId: "draft-uuid",
      activeVersionId: "published-uuid",
      hasUnpublishedChanges: true,
    };

    const canvas = Object.create(WorkflowCanvas.prototype);
    Object.defineProperty(canvas, "args", {
      value: {
        workflow,
        workflowId: 1,
        nodes: [{ clientId: "node-1", type: "trigger:manual" }],
        get workflowPublished() {
          return workflow.activeVersionId;
        },
        get hasUnpublishedChanges() {
          return workflow.hasUnpublishedChanges;
        },
      },
    });

    await canvas.publishWorkflow();

    assert.true(canvas.publishDisabled, "publish is disabled after publish");
    assert.false(
      canvas.showPublishButton,
      "publish is hidden after publish with no draft changes"
    );
    assert.false(
      canvas.showToolbarPublishButton,
      "toolbar publish is hidden after publish with no draft changes"
    );
    assert.false(
      canvas.showUnpublishedChangesMessage,
      "unpublished changes message is hidden after publish with no draft changes"
    );
    assert.false(
      canvas.showDiscardChangesButton,
      "discard changes is hidden after publish with no draft changes"
    );

    workflow.hasUnpublishedChanges = true;

    assert.false(
      canvas.publishDisabled,
      "later draft edits can re-enable publish"
    );
    assert.true(
      canvas.showPublishButton,
      "later draft edits show publish again"
    );
    assert.false(
      canvas.showToolbarPublishButton,
      "later draft edits move publish into the unpublished changes panel"
    );
    assert.true(
      canvas.showUnpublishedChangesMessage,
      "later draft edits show the unpublished changes message"
    );
    assert.true(
      canvas.showDiscardChangesButton,
      "later draft edits show discard changes"
    );
  });

  test("unpublish closes the menu", async function (assert) {
    pretender.put("/admin/plugins/discourse-workflows/workflows/1.json", () =>
      response({})
    );

    const workflow = {
      activeVersionId: "published-uuid",
      hasUnpublishedChanges: false,
    };

    const canvas = Object.create(WorkflowCanvas.prototype);
    Object.defineProperty(canvas, "args", {
      value: {
        workflow,
        workflowId: 1,
        nodes: [{ clientId: "node-1", type: "trigger:manual" }],
        get workflowPublished() {
          return workflow.activeVersionId;
        },
      },
    });

    await canvas.unpublishWorkflow(() => assert.step("close menu"));

    assert.verifySteps(["close menu"]);
    assert.false(
      canvas.workflowPublished,
      "workflow is no longer published after unpublish"
    );
    assert.false(
      canvas.showToolbarPublishButton,
      "toolbar publish remains hidden for fully unpublished workflows"
    );
    assert.true(
      canvas.showUnpublishedChangesMessage,
      "publish status remains visible for fully unpublished workflows"
    );
    assert.false(
      canvas.showDiscardChangesButton,
      "discard changes is hidden for fully unpublished workflows"
    );
  });

  test("discard success clears unpublished changes and syncs workflow", async function (assert) {
    const restoredWorkflow = {
      id: "1",
      name: "Published workflow",
      nodes: [{ id: "published-1", type: "trigger:manual" }],
      connections: {},
      version_id: "published-uuid",
      active_version_id: "published-uuid",
      has_unpublished_changes: false,
    };

    pretender.post(
      "/admin/plugins/discourse-workflows/workflows/1/discard-draft.json",
      () => response({ workflow: restoredWorkflow })
    );

    const state = {
      hasUnpublishedChanges: true,
      workflowPublished: "published-uuid",
    };
    const canvas = Object.create(WorkflowCanvas.prototype);
    Object.defineProperty(canvas, "dialog", {
      value: {
        confirm({ message, confirmButtonLabel, cancelButtonLabel }) {
          assert.strictEqual(
            message,
            i18n("discourse_workflows.discard_changes_confirmation")
          );
          assert.strictEqual(
            confirmButtonLabel,
            "discourse_workflows.discard_changes"
          );
          assert.strictEqual(
            cancelButtonLabel,
            "discourse_workflows.keep_editing"
          );
          return true;
        },
      },
    });
    Object.defineProperty(canvas, "args", {
      value: {
        workflowId: 1,
        nodes: [{ clientId: "node-1", type: "trigger:manual" }],
        get hasUnpublishedChanges() {
          return state.hasUnpublishedChanges;
        },
        get workflowPublished() {
          return state.workflowPublished;
        },
        onDiscardWorkflow(workflow) {
          state.hasUnpublishedChanges = workflow.has_unpublished_changes;
          state.workflowPublished = workflow.active_version_id;
          assert.deepEqual(
            workflow,
            restoredWorkflow,
            "restored workflow is passed to the editor"
          );
          assert.step("discarded");
        },
      },
    });

    assert.true(
      canvas.showUnpublishedChangesMessage,
      "unpublished changes message is visible before discard"
    );

    await canvas.discardWorkflow();

    assert.verifySteps(["discarded"]);
    assert.false(
      canvas.showUnpublishedChangesMessage,
      "unpublished changes message is hidden after discard"
    );
    assert.false(
      canvas.showDiscardChangesButton,
      "discard changes is hidden after discard"
    );
  });

  test("publish is hidden until the workflow has a node", async function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);
    Object.defineProperty(canvas, "args", {
      value: {
        workflowId: 1,
        nodes: [],
        workflowPublished: null,
        hasUnpublishedChanges: true,
      },
    });

    assert.false(canvas.hasNodes, "the workflow has no nodes");
    assert.false(
      canvas.showPublishButton,
      "publish is hidden before a node is added"
    );
    assert.false(
      canvas.showToolbarPublishButton,
      "toolbar publish is hidden before a node is added"
    );
    assert.false(
      canvas.showUnpublishedChangesMessage,
      "unpublished changes publish message is hidden before a node is added"
    );

    await canvas.publishWorkflow();

    assert.strictEqual(
      canvas.workflowPublishedOverride,
      null,
      "publish action does not optimistically mark an empty workflow published"
    );

    canvas.args.nodes.push({ clientId: "node-1", type: "trigger:manual" });

    assert.false(
      canvas.showToolbarPublishButton,
      "toolbar publish stays hidden once a node exists"
    );
    assert.true(
      canvas.showUnpublishedChangesMessage,
      "publish status is shown once a node exists"
    );
    assert.false(
      canvas.showDiscardChangesButton,
      "discard changes is hidden for an unpublished workflow"
    );
  });

  test("translateSelected moves selected sticky notes and selected nodes", async function (assert) {
    const movedStickyNotes = [];
    let translatedEntities;
    const canvas = Object.create(WorkflowCanvas.prototype);

    Object.defineProperty(canvas, "args", {
      value: {
        stickyNotes: [
          { clientId: "note-1", position: { x: 10, y: 20 } },
          { clientId: "note-2", position: { x: 30, y: 40 } },
          { clientId: "note-3", position: { x: 50, y: 60 } },
        ],
        onStickyNoteMove(clientId, position) {
          movedStickyNotes.push({ clientId, position });
        },
      },
    });
    canvas.rete = {
      getSelectedIds() {
        return {
          nodeIds: new Set(["node-1"]),
          stickyNoteIds: new Set(["note-1", "note-2", "note-3"]),
        };
      },
      async translateSelectedEntities(...args) {
        translatedEntities = args;
      },
    };

    await canvas.translateSelected("note-1", 5, 10);

    assert.deepEqual(
      movedStickyNotes,
      [
        { clientId: "note-2", position: { x: 35, y: 50 } },
        { clientId: "note-3", position: { x: 55, y: 70 } },
      ],
      "non-dragged selected sticky notes move by the drag delta"
    );
    assert.deepEqual(
      translatedEntities,
      ["note-1", "sticky-note", 5, 10, { labels: ["node"] }],
      "Rete translates only selected nodes for sticky-note drags"
    );
  });
});
