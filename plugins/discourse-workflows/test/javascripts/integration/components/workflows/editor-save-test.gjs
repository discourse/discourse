import { render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

let editor;
let editedNodes;

class TestEditor extends WorkflowsEditor {
  constructor() {
    super(...arguments);
    editor = this;
    editedNodes = [];
  }

  editNode(clientId) {
    editedNodes.push(clientId);
  }

  <template></template>
}

function savingWorkflow(nodes) {
  const saves = [];
  const workflow = {
    nodes,
    connections: {},
    setProperties(properties) {
      Object.assign(this, properties);
    },
    graphProperties() {
      return { nodes: this.nodes };
    },
    save() {
      return new Promise((resolve) =>
        saves.push({ nodes: structuredClone(this.nodes), resolve })
      );
    },
  };
  return { workflow, saves };
}

async function renderEditor(workflow) {
  await render(<template><TestEditor @workflow={{workflow}} /></template>);

  const data = {
    nodes: workflow.nodes.map((node) => WorkflowNode.create(node)),
    connections: [],
    stickyNotes: [],
  };
  editor.registerApi({
    get: (key) => data[key],
    set: (key, value) => (data[key] = value),
  });
}

module("Integration | Component | workflows editor saves", function (hooks) {
  setupRenderingTest(hooks);

  test("a waiting save keeps edits made while another save is in flight", async function (assert) {
    const { workflow, saves } = savingWorkflow([
      { clientId: "n1", type: "action:log", name: "Log", configuration: {} },
    ]);
    await renderEditor(workflow);

    const first = editor.handleSubmit();
    editor.formApi.set("nodes", [
      WorkflowNode.create({
        clientId: "n1",
        type: "action:log",
        name: "Log",
        configuration: { message: "Y" },
      }),
    ]);
    const second = editor.handleSubmit({ throwOnError: true });
    saves[0].resolve();
    await first;
    await waitUntil(() => saves.length === 2);
    saves[1].resolve();
    await second;

    assert.strictEqual(saves[1].nodes[0].configuration.message, "Y");
  });

  test("upgradeNode is not undoable", async function (assert) {
    const { workflow, saves } = savingWorkflow([
      { clientId: "n1", type: "action:log", name: "Log", typeVersion: "1.0" },
    ]);
    await renderEditor(workflow);

    const upgrading = editor.upgradeNode("n1");
    await waitUntil(() => saves.length === 1);
    saves[0].resolve();
    await upgrading;

    assert.false(editor.undoManager.hasPendingCapture);
    assert.deepEqual(editedNodes, ["n1"]);
  });

  test("upgradeNode does not reopen the node once the editor is destroyed", async function (assert) {
    const { workflow, saves } = savingWorkflow([
      { clientId: "n1", type: "action:log", name: "Log", typeVersion: "1.0" },
    ]);
    await renderEditor(workflow);

    const upgrading = editor.upgradeNode("n1");
    await waitUntil(() => saves.length === 1);
    await render(<template></template>);
    saves[0].resolve();
    await upgrading;

    assert.deepEqual(editedNodes, []);
  });
});
