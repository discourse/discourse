import { module, test } from "qunit";
import {
  ancestorOutputNodes,
  inputConnectionsForNode,
  outputSchemaForNode,
  previousNodeForConnection,
  resolveDeclaredOutputSchemas,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/schema-graph";

const DRAFT_URI = "https://json-schema.org/draft/2020-12/schema";

function objectSchema(properties, extra = {}) {
  return { type: "object", properties, ...extra };
}

function prop(name, type) {
  return objectSchema({ [name]: { type } });
}

function node(clientId, type, extra = {}) {
  return { clientId, type, typeVersion: "1.0", ...extra };
}

function conn(sourceClientId, targetClientId, extra = {}) {
  return { sourceClientId, targetClientId, ...extra };
}

function nodeType(name, contracts) {
  return { name, versions: { "1.0": { output_contracts: contracts } } };
}

function triggerType(name, schema) {
  return nodeType(name, [{ schema }]);
}

const PASSTHROUGH_TYPE = nodeType("flow:passthrough", [
  { mode: "passthrough" },
]);
const UNKNOWN_TRIGGER_TYPE = {
  name: "trigger:unknown",
  versions: { "1.0": {} },
};

module("Unit | lib | discourse-workflows | schema-graph", function () {
  test("output positions, visited nodes and out-of-graph nodes", function (assert) {
    const kept = prop("kept", "boolean");
    const rejected = prop("rejected", "boolean");
    const source = node("source", "condition:branch");
    const nodeTypes = [
      nodeType("condition:branch", [{ schema: kept }, { schema: rejected }]),
      PASSTHROUGH_TYPE,
    ];
    const graph = {
      nodes: [source, node("target", "flow:passthrough")],
      connections: [
        conn("source", "target", { sourceOutputIndex: 1, targetInputIndex: 1 }),
      ],
      nodeTypes,
    };
    const out = (n, opts) => outputSchemaForNode(n, graph, opts);

    assert.deepEqual(
      resolveDeclaredOutputSchemas(graph).get("source"),
      [kept, rejected],
      "each output port resolves its own schema"
    );
    assert.deepEqual(
      out(source, { outputIndex: 1 }),
      rejected,
      "outputIndex selects the port on the resolved node"
    );
    assert.deepEqual(out(graph.nodes[1]), rejected, "routes the source port");

    const resolved = resolveDeclaredOutputSchemas(graph, {
      visited: new Set(["source"]),
    });
    assert.false(resolved.has("source"), "visited nodes are not resolved");
    assert.deepEqual(resolved.get("target"), [{}], "visited links ignored");
    assert.deepEqual(
      out(source, { visited: new Set(["source"]) }),
      {},
      "a visited node resolves to unknown"
    );
    assert.deepEqual(out(null), {}, "a missing node resolves to unknown");

    const detached = node("detached", "flow:passthrough");
    const partial = {
      nodes: [source],
      connections: [conn("source", "detached")],
      nodeTypes,
    };
    assert.deepEqual(
      outputSchemaForNode(detached, partial),
      kept,
      "a node missing from the graph is appended to the resolution graph"
    );
    assert.strictEqual(partial.nodes.length, 1, "the graph is left untouched");
  });

  test("merge contracts resolve saved versions and overlay shallowly", function (assert) {
    const input = objectSchema(
      { root: { type: "string" }, shared: prop("left", "string") },
      { required: ["shared"] }
    );
    const declared = objectSchema(
      { shared: prop("own", "boolean"), extra: { type: "integer" } },
      { required: ["extra"] }
    );
    const v1 = { version: "1.0", output_contracts: [{ schema: input }] };
    const v2 = {
      version: "2.0",
      output_contracts: [{ schema: prop("latest", "boolean") }],
    };
    const staleLatest = {
      version: "2.0",
      output_contracts: [{ mode: "merge", schema: prop("latest", "boolean") }],
    };
    const merge = node("merge", "action:merge");
    const stale = node("stale", "action:versioned");
    const noOverlay = node("no-overlay", "action:no-overlay");
    const overlayOnly = node("overlay-only", "action:merge");
    const graph = {
      nodes: [
        node("source", "trigger:versioned"),
        node("unknown-source", "trigger:unknown"),
        merge,
        stale,
        noOverlay,
        overlayOnly,
      ],
      connections: [
        conn("source", "merge"),
        conn("source", "stale"),
        conn("source", "no-overlay"),
        conn("unknown-source", "overlay-only"),
      ],
      nodeTypes: [
        {
          name: "trigger:versioned",
          latest: v2,
          versions: { "1.0": v1, "2.0": v2 },
        },
        {
          name: "action:versioned",
          ...staleLatest,
          latest: staleLatest,
          versions: { "1.0": { version: "1.0" }, "2.0": staleLatest },
        },
        nodeType("action:merge", [{ mode: "merge", schema: declared }]),
        nodeType("action:no-overlay", [{ mode: "merge" }]),
        UNKNOWN_TRIGGER_TYPE,
      ],
    };
    const out = (n) => outputSchemaForNode(n, graph);

    assert.deepEqual(
      out(merge),
      objectSchema(
        {
          root: { type: "string" },
          shared: prop("own", "boolean"),
          extra: { type: "integer" },
        },
        { required: ["shared", "extra"] }
      ),
      "the saved trigger version feeds the merge, which keeps input root properties, replaces a colliding property wholesale and unions required"
    );
    assert.deepEqual(out(stale), {}, "saved versions do not inherit latest");
    assert.deepEqual(out(noOverlay), input, "empty declarations keep input");
    assert.deepEqual(out(overlayOnly), declared, "declared replaces unknown");
  });

  test("unregistered and missing type versions resolve like the server", function (assert) {
    const v1Schema = prop("from_v1", "string");
    const v2Schema = prop("from_v2", "string");
    const legacy = { clientId: "legacy", type: "trigger:versioned" };
    const stale = node("stale", "trigger:versioned", { typeVersion: "9.0" });
    const current = node("current", "trigger:versioned");
    const join = node("join", "flow:passthrough");
    const graph = {
      nodes: [legacy, stale, current, join],
      connections: [conn("current", "join"), conn("stale", "join")],
      nodeTypes: [
        {
          name: "trigger:versioned",
          latest: { version: "2.0", output_contracts: [{ schema: v2Schema }] },
          versions: {
            "1.0": { version: "1.0", output_contracts: [{ schema: v1Schema }] },
            "2.0": { version: "2.0", output_contracts: [{ schema: v2Schema }] },
          },
        },
        PASSTHROUGH_TYPE,
      ],
    };
    const out = (n) => outputSchemaForNode(n, graph);

    assert.deepEqual(
      out(current),
      v1Schema,
      "a registered typeVersion resolves its own declaration"
    );
    assert.deepEqual(
      out(stale),
      {},
      "an unregistered typeVersion resolves to unknown instead of latest"
    );
    assert.deepEqual(
      out(legacy),
      v1Schema,
      "a missing typeVersion resolves the default version, not latest"
    );
    assert.deepEqual(
      out(join),
      {},
      "an unknown version keeps downstream unions unknown"
    );
  });

  test("contract selection applies variants, display rules and overrides", function (assert) {
    const src = prop("source", "string");
    const hook = prop("body", "object");
    const base = prop("base", "string");
    const variant = prop("variant", "integer");
    const wait = node("wait", "flow:wait", {
      configuration: { resume: "time" },
    });
    const chooser = node("chooser", "action:chooser");
    const graph = {
      nodes: [node("source", "trigger:source"), wait, chooser],
      connections: [conn("source", "wait"), conn("source", "chooser")],
      nodeTypes: [
        triggerType("trigger:source", src),
        nodeType("flow:wait", [
          {
            variants: [
              {
                mode: "passthrough",
                display_options: { show: { resume: ["time"] } },
              },
              {
                schema: hook,
                mode: "replace",
                display_options: { show: { resume: ["webhook"] } },
              },
            ],
          },
        ]),
        nodeType("action:chooser", [
          {
            schema: base,
            display_options: { show: { mode: ["base"] } },
            variants: [
              {
                schema: variant,
                display_options: { show: { mode: ["variant"] } },
              },
            ],
          },
        ]),
      ],
    };
    const out = (n, opts) => outputSchemaForNode(n, graph, opts);

    assert.deepEqual(out(wait), src, "stored config picks passthrough");
    assert.deepEqual(
      out(wait, { configuration: { resume: "webhook" } }),
      hook,
      "a current configuration override selects the replacement variant"
    );
    assert.deepEqual(
      resolveDeclaredOutputSchemas(graph, {
        configurationOverrides: new Map([["wait", { resume: "webhook" }]]),
      }).get("wait"),
      [hook],
      "graph-level configuration overrides select the same variant"
    );
    assert.deepEqual(
      out(chooser, { configuration: { mode: "variant" } }),
      variant,
      "a matching variant wins over the base contract"
    );
    assert.deepEqual(
      out(chooser, { configuration: { mode: "base" } }),
      base,
      "the base contract applies when only its display options match and replace ignores the connected input"
    );
    assert.deepEqual(
      out(chooser, { configuration: { mode: "other" } }),
      {},
      "no matching contract resolves to unknown without passing the input through"
    );
  });

  test("joins, union contracts and cycles resolve across the graph", function (assert) {
    const str = prop("v", "string");
    const num = prop("v", "integer");
    const third = prop("t", "boolean");
    const join = node("join", "flow:passthrough");
    const dedup = node("dedup", "flow:passthrough");
    const pjoin = node("pjoin", "flow:passthrough");
    const extend = node("extend", "union:extend");
    const same = node("same", "union:same");
    const chain = node("chain", "union:chain");
    const punion = node("punion", "union:extend");
    const seededA = node("seeded-a", "flow:passthrough");
    const loopA = node("loop-a", "flow:passthrough");
    const cjoin = node("cjoin", "flow:passthrough");
    const graph = {
      nodes: [
        node("string-source", "trigger:string"),
        node("number-source", "trigger:number"),
        node("string-twin", "trigger:string"),
        node("unknown-source", "trigger:unknown"),
        node("seeded-b", "flow:passthrough"),
        node("loop-b", "flow:passthrough"),
        join,
        dedup,
        pjoin,
        extend,
        same,
        chain,
        punion,
        seededA,
        loopA,
        cjoin,
      ],
      connections: [
        conn("string-source", "join"),
        conn("number-source", "join"),
        conn("string-source", "dedup"),
        conn("string-twin", "dedup"),
        conn("string-source", "pjoin"),
        conn("unknown-source", "pjoin"),
        conn("string-source", "extend"),
        conn("string-source", "same"),
        conn("extend", "chain"),
        conn("unknown-source", "punion"),
        conn("string-source", "seeded-a"),
        conn("seeded-a", "seeded-b"),
        conn("seeded-b", "seeded-a"),
        conn("loop-a", "loop-b"),
        conn("loop-b", "loop-a"),
        conn("string-source", "cjoin"),
        conn("loop-a", "cjoin"),
      ],
      nodeTypes: [
        triggerType("trigger:string", str),
        triggerType("trigger:number", num),
        UNKNOWN_TRIGGER_TYPE,
        PASSTHROUGH_TYPE,
        nodeType("union:extend", [{ mode: "union", schema: num }]),
        nodeType("union:same", [{ mode: "union", schema: str }]),
        nodeType("union:chain", [{ mode: "union", schema: third }]),
      ],
    };
    const out = (n) => outputSchemaForNode(n, graph);

    assert.deepEqual(
      out(join),
      { $schema: DRAFT_URI, anyOf: [num, str] },
      "branch joins keep every incoming schema in canonical connection order"
    );
    assert.deepEqual(out(dedup), str, "identical branches collapse into one");
    assert.deepEqual(out(pjoin), {}, "an unknown branch poisons the join");
    assert.deepEqual(
      out(extend),
      { $schema: DRAFT_URI, anyOf: [str, num] },
      "the declared union schema becomes an extra anyOf alternative"
    );
    assert.deepEqual(out(same), str, "identical declared alternatives dedup");
    assert.deepEqual(
      out(chain),
      { $schema: DRAFT_URI, anyOf: [str, num, third] },
      "nested anyOf branches are flattened"
    );
    assert.deepEqual(out(punion), {}, "an unknown input poisons the union");
    assert.deepEqual(out(seededA), str, "a seeded cycle propagates the seed");
    assert.deepEqual(out(loopA), {}, "an unseeded cycle resolves to unknown");
    assert.deepEqual(out(cjoin), {}, "an unseeded cycle poisons joins");
  });

  test("merge contracts converge inside cycles by distributing over anyOf", function (assert) {
    const graph = {
      nodes: [
        node("seed", "trigger:seed"),
        node("first", "m:a"),
        node("second", "m:b"),
      ],
      connections: [
        conn("seed", "first"),
        conn("first", "second"),
        conn("second", "first"),
      ],
      nodeTypes: [
        triggerType("trigger:seed", prop("seed", "string")),
        nodeType("m:a", [{ mode: "merge", schema: prop("a", "string") }]),
        nodeType("m:b", [{ mode: "merge", schema: prop("b", "string") }]),
      ],
    };

    const resolved = resolveDeclaredOutputSchemas(graph);
    assert.deepEqual(
      resolved.get("second"),
      [
        objectSchema({
          seed: { type: "string" },
          a: { type: "string" },
          b: { type: "string" },
        }),
      ],
      "the loop-back merge accumulates every declared property exactly once"
    );
    assert.deepEqual(
      resolved.get("first")[0].anyOf?.length,
      2,
      "the merge inside the cycle keeps flat, bounded alternatives"
    );
  });

  test("resolution reads each declaration once and is reusable per node", function (assert) {
    const src = prop("source", "string");
    const source = node("source", "trigger:source");
    const nodes = [source];
    const connections = [];
    let previousLayer = [source];
    let reads = 0;

    for (let layer = 0; layer < 20; layer++) {
      const currentLayer = ["left", "right"].map((side) =>
        node(`${side}-${layer}`, "flow:passthrough")
      );
      nodes.push(...currentLayer);
      for (const previous of previousLayer) {
        for (const current of currentLayer) {
          connections.push(conn(previous.clientId, current.clientId));
        }
      }
      previousLayer = currentLayer;
    }

    const graph = {
      nodes: [...nodes].reverse(),
      connections,
      nodeTypes: [
        triggerType("trigger:source", src),
        {
          name: "flow:passthrough",
          versions: {
            "1.0": {
              get output_contracts() {
                reads++;
                return [{ mode: "passthrough" }];
              },
            },
          },
        },
      ],
    };

    assert.deepEqual(
      outputSchemaForNode(previousLayer[0], graph),
      src,
      "the declaration reaches the end of a reverse-ordered reconverging graph"
    );
    assert.strictEqual(reads, nodes.length - 1, "reads scale with node count");

    const outputSchemas = resolveDeclaredOutputSchemas(graph);
    const readsAfter = reads;
    outputSchemaForNode(nodes[5], graph, { outputSchemas });
    assert.strictEqual(reads, readsAfter, "lookups reuse the resolution");
  });

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
