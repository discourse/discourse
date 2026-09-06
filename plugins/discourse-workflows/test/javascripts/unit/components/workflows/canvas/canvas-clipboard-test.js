import { module, test } from "qunit";
import {
  buildCanvasClipboardPayload,
  isSerializedCanvasClipboardPayload,
  normalizeCanvasClipboardPayload,
  parseCanvasClipboardText,
  payloadForCanvasClipboardPaste,
  positionCanvasClipboardPayload,
  serializeCanvasClipboardPayload,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-clipboard";

module("Unit | Lib | workflows canvas clipboard", function () {
  test("buildCanvasClipboardPayload copies selected entities and internal connections", function (assert) {
    const payload = buildCanvasClipboardPayload(
      {
        nodes: [
          {
            clientId: "node-1",
            type: "trigger:manual",
            typeVersion: "1.0",
            name: "Manual",
            configuration: { foo: "bar" },
            position: { x: 10, y: 20 },
          },
          {
            clientId: "node-2",
            type: "action:topic",
            typeVersion: "1.0",
            name: "Topic",
            configuration: { value: 1 },
            position: { x: 100, y: 120 },
          },
          {
            clientId: "node-3",
            type: "action:post",
            typeVersion: "1.0",
            name: "Post",
            configuration: {},
          },
        ],
        connections: [
          {
            sourceClientId: "node-1",
            targetClientId: "node-2",
            sourceOutput: "main",
            targetInput: "main",
            sourceOutputIndex: 0,
            targetInputIndex: 0,
          },
          {
            sourceClientId: "node-2",
            targetClientId: "node-3",
          },
        ],
        stickyNotes: [
          {
            clientId: "note-1",
            position: { x: 1, y: 2 },
            size: { width: 100, height: 100 },
            color: "yellow",
            text: "Remember this",
          },
        ],
      },
      {
        nodeIds: new Set(["node-1", "node-2"]),
        stickyNoteIds: new Set(["note-1"]),
      }
    );

    assert.deepEqual(
      payload.nodes.map((node) => node.clientId),
      ["node-1", "node-2"],
      "selected nodes are copied"
    );
    assert.deepEqual(
      payload.connections.map((connection) => [
        connection.sourceClientId,
        connection.targetClientId,
      ]),
      [["node-1", "node-2"]],
      "only internal selected-node connections are copied"
    );
    assert.deepEqual(
      payload.stickyNotes.map((note) => note.clientId),
      ["note-1"],
      "selected sticky notes are copied"
    );
  });

  test("buildCanvasClipboardPayload returns null for an empty selection", function (assert) {
    assert.strictEqual(
      buildCanvasClipboardPayload(
        { nodes: [], connections: [], stickyNotes: [] },
        { nodeIds: new Set(), stickyNoteIds: new Set() }
      ),
      null
    );
  });

  test("serializeCanvasClipboardPayload produces readable text with an embedded payload", function (assert) {
    const payload = buildCanvasClipboardPayload(
      {
        nodes: [
          {
            clientId: "node-1",
            type: "trigger:manual",
            configuration: { label: "héllo" },
            position: { x: 10, y: 20 },
          },
        ],
      },
      { nodeIds: new Set(["node-1"]) }
    );

    const text = serializeCanvasClipboardPayload(payload);
    const parsedPayload = parseCanvasClipboardText(text);

    assert.true(
      text.startsWith("Discourse workflow selection."),
      "non-workflow paste targets receive readable text first"
    );
    assert.deepEqual(
      parsedPayload.nodes.map((node) => ({
        clientId: node.clientId,
        type: node.type,
        configuration: node.configuration,
        position: node.position,
      })),
      payload.nodes.map((node) => ({
        clientId: node.clientId,
        type: node.type,
        configuration: node.configuration,
        position: node.position,
      })),
      "embedded payload nodes can be parsed"
    );
  });

  test("parseCanvasClipboardText accepts raw payload JSON", function (assert) {
    const payload = normalizeCanvasClipboardPayload({
      type: "discourse-workflows/canvas-selection",
      version: 1,
      nodes: [{ clientId: "node-1", type: "trigger:manual" }],
      connections: [],
      stickyNotes: [],
    });

    assert.deepEqual(
      parseCanvasClipboardText(JSON.stringify(payload)),
      payload,
      "raw payloads parse for backwards-compatible debugging"
    );
  });

  test("parseCanvasClipboardText rejects invalid or unrelated text", function (assert) {
    assert.strictEqual(parseCanvasClipboardText("hello"), null);
    assert.strictEqual(parseCanvasClipboardText("{}"), null);
    assert.strictEqual(
      parseCanvasClipboardText(
        "<!-- discourse-workflows-canvas-selection:v1:not-base64 -->"
      ),
      null
    );
  });

  test("normalizeCanvasClipboardPayload deduplicates client ids and validates sticky note fields", function (assert) {
    const payload = normalizeCanvasClipboardPayload({
      type: "discourse-workflows/canvas-selection",
      version: 1,
      nodes: [
        { clientId: "node-1", type: "trigger:manual" },
        { clientId: "node-1", type: "action:topic" },
      ],
      connections: [
        { sourceClientId: "node-1", targetClientId: "node-1" },
        { sourceClientId: "node-1", targetClientId: "missing-node" },
      ],
      stickyNotes: [
        {
          clientId: "note-1",
          size: { width: "300", height: 150 },
          color: "blue",
        },
        {
          clientId: "note-2",
          size: { width: "large", height: 150 },
          color: "evil",
        },
        {
          clientId: "note-2",
          size: { width: 10, height: 10 },
          color: "yellow",
        },
      ],
    });

    assert.deepEqual(
      payload.nodes.map((node) => [node.clientId, node.type]),
      [["node-1", "trigger:manual"]],
      "duplicate node ids are dropped"
    );
    assert.deepEqual(
      payload.connections,
      [{ sourceClientId: "node-1", targetClientId: "node-1" }],
      "connections are limited to normalized nodes"
    );
    assert.deepEqual(
      payload.stickyNotes.map((note) => ({
        clientId: note.clientId,
        size: note.size,
        color: note.color,
      })),
      [
        {
          clientId: "note-1",
          size: { width: 300, height: 150 },
          color: "blue",
        },
        { clientId: "note-2", size: null, color: undefined },
      ],
      "sticky note size and color are normalized"
    );
  });

  test("isSerializedCanvasClipboardPayload tolerates clipboard line ending normalization", function (assert) {
    const payload = normalizeCanvasClipboardPayload({
      type: "discourse-workflows/canvas-selection",
      version: 1,
      nodes: [{ clientId: "node-1", type: "trigger:manual" }],
      connections: [],
      stickyNotes: [],
    });
    const serialized = serializeCanvasClipboardPayload(payload);

    assert.true(
      isSerializedCanvasClipboardPayload(
        serialized.replace(/\n/g, "\r\n"),
        serialized
      ),
      "local copies are detected after clipboard line ending conversion"
    );
  });

  test("payloadForCanvasClipboardPaste falls back to the local canvas payload", function (assert) {
    const localPayload = { nodes: [{ clientId: "local" }] };
    const systemPayload = { nodes: [{ clientId: "system" }] };

    assert.strictEqual(
      payloadForCanvasClipboardPaste(systemPayload, localPayload),
      systemPayload,
      "system clipboard workflow payloads win"
    );
    assert.strictEqual(
      payloadForCanvasClipboardPaste(null, localPayload),
      localPayload,
      "local payload is used when the system clipboard has no workflow payload"
    );
    assert.strictEqual(
      payloadForCanvasClipboardPaste(null, null),
      null,
      "empty paste sources stay empty"
    );
  });

  test("positionCanvasClipboardPayload centers pasted entities on a target", function (assert) {
    const positioned = positionCanvasClipboardPayload(
      {
        nodes: [
          { clientId: "node-1", position: { x: 10, y: 20 } },
          { clientId: "node-2", position: { x: 110, y: 120 } },
        ],
        connections: [{ sourceClientId: "node-1", targetClientId: "node-2" }],
        stickyNotes: [{ clientId: "note-1", position: { x: 60, y: 70 } }],
      },
      { target: { canvasX: 200, canvasY: 300 } }
    );

    assert.deepEqual(
      positioned.nodes.map((node) => node.position),
      [
        { x: 150, y: 250 },
        { x: 250, y: 350 },
      ],
      "nodes are moved around the target center"
    );
    assert.deepEqual(
      positioned.stickyNotes.map((note) => note.position),
      [{ x: 200, y: 300 }],
      "sticky notes are moved with the pasted selection"
    );
    assert.deepEqual(
      positioned.connections,
      [{ sourceClientId: "node-1", targetClientId: "node-2" }],
      "connections are preserved"
    );
  });

  test("positionCanvasClipboardPayload staggers positionless entities on a target", function (assert) {
    const positioned = positionCanvasClipboardPayload(
      {
        nodes: [
          { clientId: "node-1", position: { x: 10, y: 20 } },
          { clientId: "node-2" },
        ],
        stickyNotes: [{ clientId: "note-1" }],
      },
      { target: { canvasX: 100, canvasY: 100 } }
    );

    assert.deepEqual(
      positioned.nodes.map((node) => node.position),
      [
        { x: 100, y: 100 },
        { x: 120, y: 120 },
      ]
    );
    assert.deepEqual(positioned.stickyNotes[0].position, { x: 140, y: 140 });
  });

  test("positionCanvasClipboardPayload offsets local pastes without a target", function (assert) {
    const positioned = positionCanvasClipboardPayload(
      {
        nodes: [{ clientId: "node-1", position: { x: 10, y: 20 } }],
        stickyNotes: [{ clientId: "note-1", position: { x: 30, y: 40 } }],
      },
      { sourceOffset: 20 }
    );

    assert.deepEqual(positioned.nodes[0].position, { x: 30, y: 40 });
    assert.deepEqual(positioned.stickyNotes[0].position, { x: 50, y: 60 });
  });
});
