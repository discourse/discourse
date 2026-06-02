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

  test("AI proposal review replaces prompt composer", function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);

    canvas.aiGenerating = false;
    canvas.aiResponse = {
      status: "proposed_patch",
      response: {
        message: "Draft proposal ready",
        proposal: {
          operations: [{ op: "rename_node", node_id: "node-1", name: "Wait" }],
        },
      },
    };

    assert.true(
      canvas.aiShowingProposalReview,
      "proposal review is shown when a draft exists"
    );
    assert.false(
      canvas.aiShowingPromptComposer,
      "prompt composer is hidden while reviewing a draft"
    );
    assert.strictEqual(
      canvas.aiResponseMessage,
      null,
      "proposal response message is hidden to avoid duplicate review copy"
    );
  });

  test("AI clarification questions advance one at a time", async function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);

    canvas.aiGenerating = false;
    canvas.aiClarificationQuestionIndex = 0;
    canvas.aiResponse = {
      status: "needs_clarification",
      response: {
        questions: [
          { id: "scope", question: "Scope?", options: ["General"] },
          { id: "users", question: "Users?", options: ["TL2"] },
        ],
      },
    };
    Object.defineProperty(canvas, "aiClarificationCurrentQuestionDisabled", {
      value: false,
    });

    assert.strictEqual(
      canvas.aiCurrentQuestionNumber,
      1,
      "starts on the first question"
    );
    assert.strictEqual(
      canvas.aiQuestionText(canvas.aiCurrentQuestion),
      "Scope?",
      "only the first question is current"
    );
    assert.strictEqual(
      canvas.aiClarificationContinueLabel,
      i18n("discourse_workflows.ai.next_question"),
      "non-final questions use a next label"
    );

    await canvas.continueAiClarificationQuestion();

    assert.strictEqual(
      canvas.aiCurrentQuestionNumber,
      2,
      "moves to the second question"
    );
    assert.strictEqual(
      canvas.aiQuestionText(canvas.aiCurrentQuestion),
      "Users?",
      "the second question becomes current"
    );

    canvas.previousAiClarificationQuestion();

    assert.strictEqual(
      canvas.aiCurrentQuestionNumber,
      1,
      "can move back to the previous question"
    );

    await canvas.continueAiClarificationQuestion();
    Object.defineProperty(canvas, "submitAiClarification", {
      value: async () => assert.step("submitted"),
    });

    assert.strictEqual(
      canvas.aiClarificationContinueLabel,
      i18n("discourse_workflows.ai.continue"),
      "the final question uses the continue label"
    );

    await canvas.continueAiClarificationQuestion();

    assert.verifySteps(["submitted"]);
  });

  test("AI progress is shown only while generating", function (assert) {
    const canvas = Object.create(WorkflowCanvas.prototype);

    canvas.aiProgressEvents = [{ stage: "queued" }];
    canvas.aiGenerating = false;

    assert.false(
      canvas.aiShowingProgress,
      "completed authoring does not show old progress"
    );

    canvas.aiGenerating = true;

    assert.true(
      canvas.aiShowingProgress,
      "active authoring shows progress events"
    );

    canvas.aiProgressEvents = [];

    assert.false(
      canvas.aiShowingProgress,
      "active authoring without events does not show progress"
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
        workflowName: "Workflow",
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
        workflowName: "Workflow",
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
        workflowName: "Workflow",
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
});
