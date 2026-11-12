import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";
import WorkflowConnection from "discourse/plugins/discourse-workflows/admin/models/workflow-connection";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

const OUTPUT_SCHEMAS_PATH =
  "/admin/plugins/discourse-workflows/output-schemas.json";
const SCHEMAS = {
  "client-form": [{ type: "object", properties: { grosse: {} } }],
};

function graph() {
  const nodes = [
    WorkflowNode.create({
      id: "42",
      clientId: "client-form",
      type: "trigger:form",
      name: "Form",
      parameters: { form_fields: { values: [{ field_label: "Größe" }] } },
    }),
    WorkflowNode.create({
      clientId: "client-log",
      type: "action:log",
      name: "Log",
    }),
  ];
  const connections = [
    WorkflowConnection.create({
      sourceClientId: "client-form",
      targetClientId: "client-log",
    }),
  ];
  return { nodes, connections };
}

module("Unit | lib | discourse-workflows | editor-session", function (hooks) {
  setupTest(hooks);

  test("loadOutputSchemas posts the draft graph keyed by client id", async function (assert) {
    let body;
    pretender.post(OUTPUT_SCHEMAS_PATH, (request) => {
      body = JSON.parse(request.requestBody);
      return response(200, { output_schemas: SCHEMAS });
    });
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);

    await session.loadOutputSchemas(nodes, connections);

    assert.deepEqual(
      body.nodes.map((node) => node.id),
      ["client-form", "client-log"]
    );
    assert.deepEqual(body.nodes[0].parameters, nodes[0].parameters);
    assert.deepEqual(body.connections, {
      Form: { main: [[{ node: "Log", type: "main", index: 0 }]] },
    });
    assert.deepEqual(session.outputSchemas, SCHEMAS);
  });

  test("loadOutputSchemas drops responses that arrive after the context closed", async function (assert) {
    pretender.post(OUTPUT_SCHEMAS_PATH, () =>
      response(200, { output_schemas: SCHEMAS })
    );
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);

    const loading = session.loadOutputSchemas(nodes, connections);
    session.clearEditingContext();
    await loading;

    assert.deepEqual(session.outputSchemas, {});
  });

  test("loadOutputSchemas falls back to no schemas when the request fails", async function (assert) {
    pretender.post(OUTPUT_SCHEMAS_PATH, () => response(422, {}));
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);

    await session.loadOutputSchemas(nodes, connections);

    assert.deepEqual(session.outputSchemas, {});
  });

  test("loadOutputSchemas skips the request once the context closed", async function (assert) {
    let requested = false;
    pretender.post(OUTPUT_SCHEMAS_PATH, () => {
      requested = true;
      return response(200, { output_schemas: SCHEMAS });
    });
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);
    session.clearEditingContext();

    await session.loadOutputSchemas(nodes, connections);

    assert.false(requested);
    assert.deepEqual(session.outputSchemas, {});
  });

  test("scheduleOutputSchemas sends only the latest graph once settled", async function (assert) {
    const bodies = [];
    pretender.post(OUTPUT_SCHEMAS_PATH, (request) => {
      bodies.push(JSON.parse(request.requestBody));
      return response(200, { output_schemas: SCHEMAS });
    });
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);

    session.scheduleOutputSchemas(nodes, connections);
    session.scheduleOutputSchemas(nodes.slice(0, 1), connections);
    await settled();

    assert.strictEqual(bodies.length, 1);
    assert.deepEqual(
      bodies[0].nodes.map((node) => node.id),
      ["client-form"]
    );
    assert.deepEqual(session.outputSchemas, SCHEMAS);
  });

  test("loadOutputSchemas skips unchanged graphs and keeps equal schemas", async function (assert) {
    let requests = 0;
    pretender.post(OUTPUT_SCHEMAS_PATH, () => {
      requests++;
      return response(200, { output_schemas: SCHEMAS });
    });
    const { nodes, connections } = graph();
    const session = new WorkflowEditorSession();
    session.setEditingContext(nodes[1], nodes, connections);

    await session.loadOutputSchemas(nodes, connections);
    const loaded = session.outputSchemas;
    nodes[1].position = { x: 10, y: 10 };
    await session.loadOutputSchemas(nodes, connections);

    assert.strictEqual(requests, 1);

    nodes[0].configuration = { form_fields: { values: [] } };
    await session.loadOutputSchemas(nodes, connections);

    assert.strictEqual(requests, 2);
    assert.strictEqual(session.outputSchemas, loaded);
  });
});
