import { module, test } from "qunit";
import { i18n } from "discourse-i18n";
import WorkflowsEditor, {
  isNodeUnavailable,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";

function buildEditor(workflow, dialog = {}) {
  const editor = Object.create(WorkflowsEditor.prototype);
  editor.allowUnpublishedDraftTransition = false;

  Object.defineProperty(editor, "args", {
    value: { workflow },
  });
  Object.defineProperty(editor, "dialog", {
    value: dialog,
  });

  return editor;
}

function setFormApi(editor, data) {
  Object.defineProperty(editor, "formApi", {
    value: {
      get(key) {
        return data[key];
      },
    },
  });
}

function setRouter(editor, assert) {
  Object.defineProperty(editor, "router", {
    value: {
      transitionTo(routeName, options) {
        assert.strictEqual(
          routeName,
          "adminPlugins.show.discourse-workflows-templates"
        );
        assert.deepEqual(options.queryParams, { workflow_id: 12 });
      },
    },
  });
}

module("Unit | Component | workflows editor", function () {
  test("detects unavailable nodes", function (assert) {
    const service = {
      findNodeType(type) {
        return {
          "action:missing_plugin": null,
          "action:disabled": { latest: { available: false } },
          "action:available": { latest: { available: true } },
        }[type];
      },
    };

    assert.true(isNodeUnavailable(service, { type: "action:missing_plugin" }));
    assert.true(isNodeUnavailable(service, { type: "action:disabled" }));
    assert.false(isNodeUnavailable(service, { type: "action:available" }));
  });

  test("editNode does not open unavailable nodes", function (assert) {
    assert.expect(0);

    const editor = buildEditor({});
    setFormApi(editor, {
      nodes: [{ clientId: "node-1", type: "action:missing_plugin" }],
      connections: [],
    });

    Object.defineProperty(editor, "workflowsNodeTypes", {
      value: {
        findNodeType() {
          return null;
        },
      },
    });
    Object.defineProperty(editor, "modal", {
      value: {
        show() {
          assert.true(false, "modal should not open");
        },
      },
    });

    editor.editNode("node-1");
  });

  test("beforeunload warns when the workflow has an unpublished draft", function (assert) {
    const editor = buildEditor({
      activeVersionId: "published-version",
      hasUnpublishedChanges: true,
    });
    const event = {
      returnValue: null,
      preventDefault() {
        assert.step("prevented");
      },
    };

    const message = editor.handleBeforeUnload(event);

    assert.verifySteps(["prevented"]);
    assert.strictEqual(
      message,
      i18n("discourse_workflows.unpublished_changes_confirmation")
    );
    assert.strictEqual(event.returnValue, message);
  });

  test("beforeunload does not warn when the workflow has no unpublished draft", function (assert) {
    const editor = buildEditor({ hasUnpublishedChanges: false });
    const event = {
      preventDefault() {
        assert.true(false, "preventDefault should not be called");
      },
    };

    assert.strictEqual(editor.handleBeforeUnload(event), undefined);
  });

  test("beforeunload does not warn for workflows that were never published", function (assert) {
    const editor = buildEditor({
      activeVersionId: null,
      hasUnpublishedChanges: true,
    });
    const event = {
      preventDefault() {
        assert.true(false, "preventDefault should not be called");
      },
    };

    assert.strictEqual(editor.handleBeforeUnload(event), undefined);
  });

  test("beforeunload warns while a draft save is in flight", function (assert) {
    const editor = buildEditor({ hasUnpublishedChanges: false });
    const event = {
      returnValue: null,
      preventDefault() {
        assert.step("prevented");
      },
    };

    editor.saving = true;

    const message = editor.handleBeforeUnload(event);

    assert.verifySteps(["prevented"]);
    assert.strictEqual(
      message,
      i18n("discourse_workflows.unpublished_changes_confirmation")
    );
  });

  test("route changes ask for confirmation when the workflow has an unpublished draft", function (assert) {
    const transition = {
      isAborted: false,
      queryParamsOnly: false,
      from: { name: "adminPlugins.show.discourse-workflows.show.index" },
      to: { name: "adminPlugins.show.discourse-workflows" },
      abort() {
        assert.step("aborted");
      },
      retry() {
        assert.step("retried");
      },
    };
    const dialog = {
      dialog({ class: dialogClass, message, buttons }) {
        assert.strictEqual(dialogClass, "workflows-unpublished-draft-dialog");
        assert.strictEqual(
          message,
          i18n("discourse_workflows.unpublished_changes_confirmation")
        );
        assert.deepEqual(
          buttons.map((button) => button.label),
          [
            i18n("discourse_workflows.leave_without_publishing"),
            i18n("discourse_workflows.keep_editing"),
            i18n("discourse_workflows.discard_changes"),
          ]
        );
        assert.true(
          buttons[2].class.includes(
            "workflows-unpublished-draft-dialog__discard-btn"
          ),
          "discard button is aligned separately"
        );
        buttons[0].action();
      },
    };
    const editor = buildEditor(
      {
        activeVersionId: "published-version",
        hasUnpublishedChanges: true,
      },
      dialog
    );

    editor.confirmUnpublishedDraftTransition(transition);

    assert.true(editor.allowUnpublishedDraftTransition);
    assert.verifySteps(["aborted", "retried"]);
  });

  test("route changes can discard changes before retrying", async function (assert) {
    const transition = {
      isAborted: false,
      queryParamsOnly: false,
      from: { name: "adminPlugins.show.discourse-workflows.show.index" },
      to: { name: "adminPlugins.show.discourse-workflows" },
      abort() {
        assert.step("aborted");
      },
      retry() {
        assert.step("retried");
      },
    };
    let discardAction;
    const dialog = {
      dialog({ buttons }) {
        discardAction = buttons[2].action;
      },
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
        assert.step("confirmed discard");
        return true;
      },
    };
    const editor = buildEditor(
      {
        activeVersionId: "published-version",
        hasUnpublishedChanges: true,
      },
      dialog
    );
    editor.discardWorkflowDraft = async () => assert.step("discarded");

    editor.confirmUnpublishedDraftTransition(transition);
    await discardAction();

    assert.true(editor.allowUnpublishedDraftTransition);
    assert.verifySteps([
      "aborted",
      "confirmed discard",
      "discarded",
      "retried",
    ]);
  });

  test("browseTemplates skips draft confirmation for an empty workflow", function (assert) {
    const editor = buildEditor({ id: 12, hasUnpublishedChanges: true });
    setFormApi(editor, { nodes: [], stickyNotes: [] });
    setRouter(editor, assert);

    editor.browseTemplates();

    assert.true(editor.allowUnpublishedDraftTransition);
  });

  test("browseTemplates keeps draft confirmation for non-empty workflows", function (assert) {
    const editor = buildEditor({ id: 12, hasUnpublishedChanges: true });
    setFormApi(editor, { nodes: [{ id: "n1" }], stickyNotes: [] });
    setRouter(editor, assert);

    editor.browseTemplates();

    assert.false(editor.allowUnpublishedDraftTransition);
  });

  test("node panel hides triggers when adding after a trigger", function (assert) {
    const editor = buildEditor({ id: 12 });
    editor.nodePanelNodeTypes = [
      { identifier: "trigger:manual" },
      { identifier: "action:topic" },
    ];
    editor.nodePanelContext = { sourceClientId: "trigger-1" };
    editor.nodePanelSearchTerm = "";
    setFormApi(editor, {
      nodes: [{ clientId: "trigger-1", type: "trigger:manual" }],
    });

    assert.deepEqual(
      editor.filteredNodePanelTypes.map((nodeType) => nodeType.identifier),
      ["action:topic"]
    );
  });

  test("node panel keeps triggers when adding from the canvas", function (assert) {
    const editor = buildEditor({ id: 12 });
    editor.nodePanelNodeTypes = [
      { identifier: "trigger:manual" },
      { identifier: "action:topic" },
    ];
    editor.nodePanelContext = { canvasX: 10, canvasY: 20 };
    editor.nodePanelSearchTerm = "";

    assert.deepEqual(
      editor.filteredNodePanelTypes.map((nodeType) => nodeType.identifier),
      ["trigger:manual", "action:topic"]
    );
  });
});
