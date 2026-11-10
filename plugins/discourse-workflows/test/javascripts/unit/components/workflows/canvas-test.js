import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
  });

  test("hasNodes reflects whether the canvas has any nodes", function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);
    Object.defineProperty(canvas, "args", {
      value: { nodes: [] },
    });

    assert.false(canvas.hasNodes, "the workflow has no nodes");

    canvas.args.nodes.push({ clientId: "node-1", type: "trigger:manual" });

    assert.true(canvas.hasNodes, "the workflow has a node");
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
