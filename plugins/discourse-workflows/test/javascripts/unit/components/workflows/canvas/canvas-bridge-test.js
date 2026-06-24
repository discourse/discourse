import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { createReteEditor } from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/rete-editor";
import { buildConnectedOutputsIndex } from "discourse/plugins/discourse-workflows/admin/lib/workflows/graph-constants";

const NODE_TYPES = [
  {
    identifier: "trigger:manual",
    ports: [{ key: "main", primary: true }],
  },
  {
    identifier: "action:data_table",
    ports: [
      { key: "results", primary: true, label: "Results" },
      { key: "no_results", label: "No results" },
    ],
  },
  {
    identifier: "action:http_request",
    ports: [{ key: "main", primary: true }],
  },
  {
    identifier: "flow:loop_over_items",
    inputs: [{ key: "main", multiple: true }],
    ports: [
      { key: "done", primary: true },
      { key: "loop", primary: false },
    ],
  },
  {
    identifier: "flow:merge",
    inputs: [
      {
        key: "main",
        required: false,
        multiple: true,
      },
    ],
    ports: [{ key: "main", primary: true }],
  },
];

function noopCallbacks(overrides = {}) {
  return {
    onNodeDragged() {},
    onNodeDragEnd() {},
    onNodePicked() {},
    onNodeDoubleClick() {},
    onNodeDelete() {},
    onManualTrigger() {},
    onCanvasPointerDown() {},
    onConnectionCreated() {},
    onTransformChanged() {},
    ...overrides,
  };
}

module("Unit | Canvas Bridge", function (hooks) {
  setupTest(hooks);

  let container;

  hooks.beforeEach(function () {
    container = document.createElement("div");
    container.style.cssText = "width:800px;height:600px;position:relative";
    document.getElementById("qunit-fixture").appendChild(container);
  });

  test("create returns a bridge with empty state", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    assert.strictEqual(bridge.nodeCount, 0);
    assert.deepEqual(bridge.renderer.nodeEntryList, []);
    assert.deepEqual(bridge.renderer.connectionEntryList, []);
    assert.deepEqual(bridge.renderer.outputHandleEntryList, []);
    assert.strictEqual(typeof bridge.transform.k, "number");

    bridge.destroy();
  });

  test("syncState adds and removes nodes", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "n1",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "n2",
          type: "action:http_request",
          position: { x: 200, y: 0 },
        },
      ],
      []
    );

    assert.strictEqual(bridge.nodeCount, 2);
    assert.strictEqual(bridge.renderer.nodeEntryList.length, 2);

    await bridge.syncState(
      [
        {
          clientId: "n1",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
      ],
      []
    );

    assert.strictEqual(bridge.nodeCount, 1);
    assert.strictEqual(bridge.renderer.nodeEntryList.length, 1);

    bridge.destroy();
  });

  test("syncState manages connections and creates connection entries", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "n1",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "n2",
          type: "action:http_request",
          position: { x: 200, y: 0 },
        },
      ],
      [{ sourceClientId: "n1", sourceOutput: "main", targetClientId: "n2" }]
    );

    assert.true(
      bridge.renderer.connectionEntryList.length > 0,
      "connection entries created"
    );

    bridge.destroy();
  });

  test("connection entries carry pre-resolved client IDs", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "n1",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "n2",
          type: "action:http_request",
          position: { x: 200, y: 0 },
        },
      ],
      [{ sourceClientId: "n1", sourceOutput: "main", targetClientId: "n2" }]
    );

    const entry = bridge.renderer.connectionEntryList[0];
    assert.strictEqual(entry.connectionInfo.sourceClientId, "n1");
    assert.strictEqual(entry.connectionInfo.targetClientId, "n2");
    assert.strictEqual(entry.connectionInfo.sourceOutput, "main");

    bridge.destroy();
  });

  test("loop back connections carry pre-resolved client IDs", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "trigger",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "loop",
          type: "flow:loop_over_items",
          position: { x: 200, y: 0 },
        },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "loop",
        },
      ]
    );

    const loopBack = bridge.renderer.connectionEntryList.find(
      (e) => e.isLoopBack
    );
    assert.true(!!loopBack, "loop back entry created");
    assert.strictEqual(loopBack.loopNodeClientId, "loop");

    bridge.destroy();
  });

  test("syncState resolves index-only connections to Rete socket keys", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "loop",
          type: "flow:loop_over_items",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "body",
          type: "action:http_request",
          position: { x: 200, y: 0 },
        },
      ],
      [
        {
          sourceClientId: "loop",
          sourceOutputIndex: 1,
          targetClientId: "body",
          targetInputIndex: 0,
        },
      ]
    );

    const connection = bridge.editor.getConnections()[0];
    assert.strictEqual(connection.sourceOutput, "loop");
    assert.strictEqual(connection.targetInput, "main");

    bridge.destroy();
  });

  test("resolves arbitrary output keys to declared port indexes", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    const nodes = [
      {
        clientId: "branch",
        type: "action:data_table",
        position: { x: 0, y: 0 },
      },
      {
        clientId: "empty",
        type: "action:http_request",
        position: { x: 200, y: 0 },
      },
    ];
    const connections = [
      {
        sourceClientId: "branch",
        sourceOutput: "no_results",
        targetClientId: "empty",
      },
    ];

    await bridge.syncState(nodes, connections);

    const connection = bridge.editor.getConnections()[0];
    assert.strictEqual(connection.sourceOutput, "no_results");
    assert.strictEqual(connection.sourceOutputIndex, 1);
    assert.true(
      buildConnectedOutputsIndex([connection]).get("branch").has(1),
      "the second output is marked connected"
    );

    assert.strictEqual(
      bridge.buildDesiredGraphConnections(connections)[0].sourceOutputIndex,
      1
    );

    bridge.destroy();
  });

  test("connectioncreated reports the declared port index for arbitrary output keys", async function (assert) {
    let createdConnection;

    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks({
        onConnectionCreated(
          source,
          sourceOutput,
          target,
          targetInput,
          sourceOutputIndex,
          targetInputIndex
        ) {
          createdConnection = {
            source,
            sourceOutput,
            target,
            targetInput,
            sourceOutputIndex,
            targetInputIndex,
          };
        },
      }),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "branch",
          type: "action:data_table",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "empty",
          type: "action:http_request",
          position: { x: 200, y: 0 },
        },
      ],
      []
    );

    await bridge.addConnection("branch", "no_results", "empty");

    assert.deepEqual(createdConnection, {
      source: "branch",
      sourceOutput: "no_results",
      target: "empty",
      targetInput: "main",
      sourceOutputIndex: 1,
      targetInputIndex: 0,
    });

    bridge.destroy();
  });

  test("connectioncreated reports the next merge input index", async function (assert) {
    let createdConnection;

    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks({
        onConnectionCreated(
          source,
          sourceOutput,
          target,
          targetInput,
          sourceOutputIndex,
          targetInputIndex
        ) {
          createdConnection = {
            source,
            sourceOutput,
            target,
            targetInput,
            sourceOutputIndex,
            targetInputIndex,
          };
        },
      }),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "users",
          type: "action:http_request",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "groups",
          type: "action:http_request",
          position: { x: 0, y: 200 },
        },
        {
          clientId: "merge",
          type: "flow:merge",
          position: { x: 200, y: 100 },
        },
      ],
      [
        {
          sourceClientId: "users",
          targetClientId: "merge",
          targetInput: "main",
          targetInputIndex: 0,
        },
      ]
    );

    await bridge.addConnection("groups", "main", "merge");

    assert.deepEqual(createdConnection, {
      source: "groups",
      sourceOutput: "main",
      target: "merge",
      targetInput: "main",
      sourceOutputIndex: 0,
      targetInputIndex: 1,
    });

    assert.strictEqual(
      bridge.editor.getConnections().find((connection) => {
        return connection.source === "groups" && connection.target === "merge";
      }).targetInputIndex,
      1
    );

    bridge.destroy();
  });

  test("autoArrange returns position map keyed by client IDs", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    await bridge.syncState(
      [
        {
          clientId: "n1",
          type: "trigger:manual",
          position: { x: 0, y: 0 },
        },
        {
          clientId: "n2",
          type: "action:http_request",
          position: { x: 0, y: 0 },
        },
      ],
      [{ sourceClientId: "n1", sourceOutput: "main", targetClientId: "n2" }]
    );

    const positions = await bridge.autoArrange();
    assert.true(positions instanceof Map);
    assert.true(positions.has("n1"));
    assert.true(positions.has("n2"));
    assert.strictEqual(typeof positions.get("n1").x, "number");
    assert.strictEqual(typeof positions.get("n1").y, "number");

    bridge.destroy();
  });

  test("autoArrange is stable across a save-and-reload round trip", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    const nodes = [
      {
        clientId: "trigger",
        type: "trigger:manual",
        position: { x: 0, y: 0 },
      },
      {
        clientId: "branch",
        type: "action:data_table",
        position: { x: 0, y: 0 },
      },
      {
        clientId: "results",
        type: "action:http_request",
        position: { x: 0, y: 0 },
      },
      {
        clientId: "empty",
        type: "action:http_request",
        position: { x: 0, y: 0 },
      },
    ];
    const connections = [
      {
        sourceClientId: "trigger",
        sourceOutput: "main",
        targetClientId: "branch",
      },
      {
        sourceClientId: "branch",
        sourceOutput: "results",
        targetClientId: "results",
      },
      {
        sourceClientId: "branch",
        sourceOutput: "no_results",
        targetClientId: "empty",
      },
    ];

    await bridge.syncState(nodes, connections);

    const firstPositions = await bridge.autoArrange();

    await bridge.syncState(
      nodes.map((node) => ({
        ...node,
        position: firstPositions.get(node.clientId),
      })),
      connections
    );

    const secondPositions = await bridge.autoArrange();

    assert.deepEqual(
      Object.fromEntries(secondPositions),
      Object.fromEntries(firstPositions)
    );

    bridge.destroy();
  });

  test("containerToCanvas converts coordinates based on transform", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    const result = bridge.containerToCanvas(100, 200);
    assert.strictEqual(typeof result.canvasX, "number");
    assert.strictEqual(typeof result.canvasY, "number");

    bridge.destroy();
  });

  test("transform getter returns valid values", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });

    const t = bridge.transform;
    assert.strictEqual(typeof t.x, "number");
    assert.strictEqual(typeof t.y, "number");
    assert.strictEqual(typeof t.k, "number");
    assert.true(t.k > 0);

    bridge.destroy();
  });

  test("onTransformChanged callback fires on zoom", async function (assert) {
    let transformValue = null;
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks({
        onTransformChanged(t) {
          transformValue = t;
        },
      }),
      nodeTypes: NODE_TYPES,
    });

    await bridge.zoomAtViewportCenter(2);
    assert.strictEqual(transformValue.k, 2);

    bridge.destroy();
  });

  test("destroy completes without error", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });
    bridge.destroy();
    assert.true(true, "destroy completed without error");
  });

  test("areaForHistory returns the area plugin for UndoManager", async function (assert) {
    const bridge = await createReteEditor(container, {
      callbacks: noopCallbacks(),
      nodeTypes: NODE_TYPES,
    });
    assert.notStrictEqual(bridge.area, undefined, "areaForHistory is truthy");
    assert.strictEqual(
      typeof bridge.area.use,
      "function",
      "areaForHistory exposes use() for plugin registration"
    );
    bridge.destroy();
  });
});
