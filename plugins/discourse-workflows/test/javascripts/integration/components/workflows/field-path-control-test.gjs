import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import FieldPathControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/field-path-control";

const NODE = {
  clientId: "summarize",
  name: "Summarize",
  type: "action:summarize",
  typeVersion: "1.0",
  parameters: {},
};

const UPSTREAM = {
  clientId: "posts",
  name: "Posts",
  type: "action:post",
  typeVersion: "1.0",
  parameters: {},
};

const GRAPH = {
  nodes: [UPSTREAM, NODE],
  connections: [
    {
      sourceClientId: "posts",
      targetClientId: "summarize",
      sourceOutputIndex: 0,
      targetInputIndex: 0,
    },
  ],
  nodeTypes: [],
};

function buildSession() {
  return {
    lastExecutionRunData: {},
    pinnedItemsForNode(name) {
      if (name === "Posts") {
        return [{ json: { topic_id: 7, username: "ann", score: 5 } }];
      }
    },
  };
}

module(
  "Integration | Component | workflows field-path-control",
  function (hooks) {
    setupRenderingTest(hooks);

    test("single mode lists input paths and stores one", async function (assert) {
      const writes = [];
      this.setProperties({
        node: NODE,
        nodes: GRAPH.nodes,
        connections: GRAPH.connections,
        nodeTypes: GRAPH.nodeTypes,
        session: buildSession(),
        schema: { ui: {} },
        field: { value: "", set: (value) => writes.push(value) },
      });

      await render(
        <template>
          <FieldPathControl
            @connections={{this.connections}}
            @field={{this.field}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </template>
      );

      const picker = selectKit(".workflows-field-path");
      await picker.expand();

      assert.deepEqual(
        picker.displayedContent().map((row) => row.name),
        ["topic_id", "username", "score"]
      );

      await picker.selectRowByValue("username");

      assert.deepEqual(writes, ["username"]);
    });

    test("multiple mode shows the stored list and appends to it", async function (assert) {
      const writes = [];
      this.setProperties({
        node: NODE,
        nodes: GRAPH.nodes,
        connections: GRAPH.connections,
        nodeTypes: GRAPH.nodeTypes,
        session: buildSession(),
        schema: { ui: { multiple: true } },
        field: {
          value: "topic_id, username",
          set: (value) => writes.push(value),
        },
      });

      await render(
        <template>
          <FieldPathControl
            @connections={{this.connections}}
            @field={{this.field}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </template>
      );

      const picker = selectKit(".workflows-field-path");

      assert.strictEqual(picker.header().value(), "topic_id,username");

      await picker.expand();
      await picker.selectRowByValue("score");

      assert.deepEqual(writes, ["topic_id, username, score"]);
    });

    test("multiple mode keeps a stored path the input no longer offers", async function (assert) {
      this.setProperties({
        node: NODE,
        nodes: GRAPH.nodes,
        connections: GRAPH.connections,
        nodeTypes: GRAPH.nodeTypes,
        session: buildSession(),
        schema: { ui: { multiple: true } },
        field: { value: "vanished_field", set: () => {} },
      });

      await render(
        <template>
          <FieldPathControl
            @connections={{this.connections}}
            @field={{this.field}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </template>
      );

      const picker = selectKit(".workflows-field-path");
      assert.strictEqual(picker.header().value(), "vanished_field");
    });
  }
);
