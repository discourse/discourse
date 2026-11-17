import { render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import WorkflowsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

const UPGRADES_URL =
  "/admin/plugins/discourse-workflows/node-types/upgrades.json";

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

function upgradesTo(node) {
  return response({
    nodes: [node],
    upgrades: [{ name: node.name, notes: [] }],
    skipped: [],
  });
}

const LOG_NODE = {
  clientId: "n1",
  type: "action:log",
  name: "Log",
  typeVersion: "1.0",
};

module("Integration | Component | workflows editor upgrades", function (hooks) {
  setupRenderingTest(hooks);

  test("upgradeNode saves the replacement the server returns", async function (assert) {
    let requested;
    pretender.post(UPGRADES_URL, (request) => {
      requested = JSON.parse(request.requestBody).nodes;
      return upgradesTo({
        id: "n1",
        type: "action:close_topic",
        typeVersion: "1.0",
        name: "Close",
        parameters: { topic_id: "1" },
        credentials: {},
      });
    });
    const { workflow, saves } = savingWorkflow([
      {
        clientId: "n1",
        type: "action:topic",
        typeVersion: "1.0",
        name: "Close",
        configuration: { operation: "close", topic_id: "1" },
      },
    ]);
    await renderEditor(workflow);

    const upgrading = editor.upgradeNode("n1");
    await waitUntil(() => saves.length === 1);
    saves[0].resolve();
    await upgrading;

    assert.deepEqual(
      requested.map(({ type, parameters }) => ({ type, parameters })),
      [
        {
          type: "action:topic",
          parameters: { operation: "close", topic_id: "1" },
        },
      ],
      "sends the node as edited"
    );
    const [saved] = saves[0].nodes;
    assert.deepEqual(
      {
        clientId: saved.clientId,
        name: saved.name,
        type: saved.type,
        typeVersion: saved.typeVersion,
        configuration: saved.configuration,
      },
      {
        clientId: "n1",
        name: "Close",
        type: "action:close_topic",
        typeVersion: "1.0",
        configuration: { topic_id: "1" },
      },
      "keeps the node and saves its replacement"
    );
    assert.deepEqual(editedNodes, ["n1"], "reopens the node");
  });

  test("upgradeNode leaves a node the server can't upgrade untouched", async function (assert) {
    pretender.post(UPGRADES_URL, () =>
      response({ nodes: [], upgrades: [], skipped: ["Log"] })
    );
    const { workflow, saves } = savingWorkflow([LOG_NODE]);
    await renderEditor(workflow);

    await editor.upgradeNode("n1");

    assert.strictEqual(saves.length, 0);
    assert.strictEqual(editor.formApi.get("nodes")[0].typeVersion, "1.0");
    assert.deepEqual(editedNodes, []);
  });

  test("upgradeNode is not undoable", async function (assert) {
    pretender.post(UPGRADES_URL, () =>
      upgradesTo({ ...LOG_NODE, id: "n1", typeVersion: "2.0" })
    );
    const { workflow, saves } = savingWorkflow([LOG_NODE]);
    await renderEditor(workflow);

    const upgrading = editor.upgradeNode("n1");
    await waitUntil(() => saves.length === 1);
    saves[0].resolve();
    await upgrading;

    assert.false(editor.undoManager.hasPendingCapture);
    assert.deepEqual(editedNodes, ["n1"]);
  });

  test("upgradeNode does not reopen the node once the editor is destroyed", async function (assert) {
    pretender.post(UPGRADES_URL, () =>
      upgradesTo({ ...LOG_NODE, id: "n1", typeVersion: "2.0" })
    );
    const { workflow, saves } = savingWorkflow([LOG_NODE]);
    await renderEditor(workflow);

    const upgrading = editor.upgradeNode("n1");
    await waitUntil(() => saves.length === 1);
    await render(<template></template>);
    saves[0].resolve();
    await upgrading;

    assert.deepEqual(editedNodes, []);
  });
});
