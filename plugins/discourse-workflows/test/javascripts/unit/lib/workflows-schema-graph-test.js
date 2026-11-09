import { module, test } from "qunit";
import {
  ancestorOutputNodes,
  inputConnectionsForNode,
  previousNodeForConnection,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/schema-graph";

function conn(sourceClientId, targetClientId, extra = {}) {
  return { sourceClientId, targetClientId, ...extra };
}

module("Unit | lib | discourse-workflows | schema-graph", function () {
  test("ancestorOutputNodes deduplicates output ports and survives cycles", function (assert) {
    const trigger = { clientId: "t" };
    const branch = { clientId: "b" };
    const current = { clientId: "c" };
    const graph = {
      nodes: [trigger, branch, current],
      connections: [
        conn("t", "b"),
        conn("c", "t"),
        conn("b", "c", { sourceOutputIndex: 0, targetInputIndex: 0 }),
        conn("b", "c", { sourceOutputIndex: 1, targetInputIndex: 1 }),
        conn("b", "c", { sourceOutputIndex: 0, targetInputIndex: 2 }),
      ],
    };

    assert.deepEqual(
      ancestorOutputNodes(current, graph),
      [
        { node: branch, outputIndex: 0 },
        { node: branch, outputIndex: 1 },
        { node: trigger, outputIndex: 0 },
      ],
      "the upstream chain is followed with deduplicated output ports"
    );
  });

  test("connection helpers order inputs and resolve source nodes", function (assert) {
    const graph = {
      connections: [
        conn("merge", "merge"),
        conn("later-input", "merge", { targetInputIndex: 1 }),
        conn("beta", "merge", { targetInputIndex: 0, sourceOutputIndex: 1 }),
        conn("zulu", "merge", { targetInputIndex: 0, sourceOutputIndex: 0 }),
        conn("alpha", "merge", { targetInputIndex: 0, sourceOutputIndex: 1 }),
      ],
    };
    const sources = (visited) =>
      inputConnectionsForNode({ clientId: "merge" }, graph, visited).map(
        (connection) => connection.sourceClientId
      );

    assert.deepEqual(
      sources(),
      ["zulu", "alpha", "beta", "later-input"],
      "connections sort by target input, source output, then source node ID, skipping self-connections"
    );
    assert.deepEqual(
      sources(new Set(["zulu"])),
      ["alpha", "beta", "later-input"],
      "connections from visited sources are excluded"
    );

    const src = { clientId: "s" };
    const g2 = { nodes: [src] };
    assert.strictEqual(previousNodeForConnection(conn("s", "x"), g2), src);
    assert.strictEqual(previousNodeForConnection(conn("nope", "x"), g2), null);
    assert.strictEqual(previousNodeForConnection(null, g2), null);
  });
});
