import { module, test } from "qunit";
import { inputFieldPathsForNode } from "discourse/plugins/discourse-workflows/admin/lib/workflows/input-fields";

const SUMMARIZE = {
  clientId: "summarize",
  name: "Topics",
  type: "action:summarize",
  typeVersion: "1.0",
  parameters: {},
};

const UPSTREAM = {
  clientId: "flatten",
  name: "Flatten posts",
  type: "action:set_fields",
  typeVersion: "1.0",
  parameters: {},
};

const GRAPH = {
  nodes: [UPSTREAM, SUMMARIZE],
  connections: [
    {
      sourceClientId: "flatten",
      targetClientId: "summarize",
      sourceOutputIndex: 0,
      targetInputIndex: 0,
    },
  ],
  nodeTypes: [],
};

function sessionWithPinnedItems(items) {
  return {
    lastExecutionRunData: {},
    pinnedItemsForNode(name) {
      return name === "Flatten posts" ? items : undefined;
    },
  };
}

module(
  "Unit | lib | discourse-workflows | inputFieldPathsForNode",
  function () {
    test("returns nothing without a node", function (assert) {
      assert.deepEqual(inputFieldPathsForNode(null, {}), []);
    });

    test("returns nothing when the node has no upstream connection", function (assert) {
      const paths = inputFieldPathsForNode(SUMMARIZE, {
        nodes: [SUMMARIZE],
        connections: [],
        nodeTypes: [],
        session: sessionWithPinnedItems([{ json: { id: 1 } }]),
      });

      assert.deepEqual(paths, []);
    });

    test("derives paths from the upstream node's pinned items", function (assert) {
      const paths = inputFieldPathsForNode(SUMMARIZE, {
        ...GRAPH,
        session: sessionWithPinnedItems([
          { json: { id: 1, topic_id: 7, username: "ann" } },
        ]),
      });

      assert.deepEqual(
        paths.map((entry) => entry.path),
        ["id", "topic_id", "username"]
      );
    });

    test("includes nested paths and their parent", function (assert) {
      const paths = inputFieldPathsForNode(SUMMARIZE, {
        ...GRAPH,
        session: sessionWithPinnedItems([
          { json: { post: { id: 1, raw: "hello" } } },
        ]),
      });

      assert.deepEqual(
        paths.map((entry) => entry.path),
        ["post", "post.id", "post.raw"]
      );
    });

    test("emits paths without an expression prefix", function (assert) {
      const paths = inputFieldPathsForNode(SUMMARIZE, {
        ...GRAPH,
        session: sessionWithPinnedItems([{ json: { topic_id: 7 } }]),
      });

      assert.false(
        paths.some((entry) => entry.path.startsWith("$json")),
        "paths are relative to the item json"
      );
    });

    test("deduplicates paths seen on more than one item", function (assert) {
      const paths = inputFieldPathsForNode(SUMMARIZE, {
        ...GRAPH,
        session: sessionWithPinnedItems([
          { json: { topic_id: 7 } },
          { json: { topic_id: 8 } },
        ]),
      });

      assert.deepEqual(
        paths.map((entry) => entry.path),
        ["topic_id"]
      );
    });
  }
);
