import { module, test } from "qunit";
import {
  buildScope,
  lookupWorkflowMethodDoc,
  resolveVariableId,
  walkScope,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

module("Unit | lib | discourse-workflows | buildScope", function () {
  test("builds $json from inputFields", function (assert) {
    const scope = buildScope({
      inputFields: [
        { key: "title", type: "string" },
        { key: "count", type: "integer" },
      ],
    });

    assert.strictEqual(scope.$json.title, "");
    assert.strictEqual(scope.$json.count, 0);
  });

  test("builds nested $json from children", function (assert) {
    const scope = buildScope({
      inputFields: [
        {
          key: "post",
          type: "object",
          children: [
            { key: "id", type: "integer" },
            { key: "raw", type: "string" },
          ],
        },
      ],
    });

    assert.strictEqual(scope.$json.post.id, 0);
    assert.strictEqual(scope.$json.post.raw, "");
  });

  test("$trigger resolves to the trigger node output, distinct from $json", function (assert) {
    const scope = buildScope({
      inputFields: [{ key: "current", type: "string" }],
      ancestorNodes: [
        {
          node: { name: "Topic Created", type: "trigger:topic_created" },
          fields: [{ key: "topic_title", type: "string" }],
        },
      ],
    });

    assert.strictEqual(scope.$trigger.topic_title, "");
    // Distinct from the current input, and the bare `trigger` name is gone.
    assert.notStrictEqual(scope.$trigger, scope.$json);
    assert.strictEqual(scope.$json.topic_title, undefined);
    assert.strictEqual(scope.trigger, undefined);
  });

  test("$trigger is an empty object when no trigger ancestor is known", function (assert) {
    const scope = buildScope({
      inputFields: [{ key: "current", type: "string" }],
    });

    assert.deepEqual(Object.keys(scope.$trigger), []);
    assert.strictEqual(scope.trigger, undefined);
  });

  test("$input.item.json aliases $json", function (assert) {
    const scope = buildScope({
      inputFields: [{ key: "title", type: "string" }],
    });

    assert.strictEqual(scope.$input.item.json, scope.$json);
    assert.strictEqual(scope.$itemIndex, 0);
  });

  test("builds $input helpers for current node input", function (assert) {
    const scope = buildScope({
      inputFields: [{ key: "title", type: "string" }],
    });

    assert.strictEqual(scope.$input.all().length, 1);
    assert.strictEqual(scope.$input.first(), scope.$input.item);
    assert.strictEqual(scope.$input.last(), scope.$input.item);
    assert.deepEqual(scope.$input.params, Object.create(null));
    assert.deepEqual(scope.$input.context, Object.create(null));
  });

  test("exposes method docs for workflow-owned scope helpers", function (assert) {
    assert.deepEqual(lookupWorkflowMethodDoc("$input", "all"), {
      detail: "()",
      info: "Returns an array of the current node's input items.",
    });
    assert.strictEqual(lookupWorkflowMethodDoc("$input", "missing"), null);
  });

  test("ancestor node outputs accessible via $()", function (assert) {
    const scope = buildScope({
      ancestorNodes: [
        {
          node: { name: "Fetch data" },
          fields: [{ key: "name", type: "string" }],
        },
      ],
    });

    const ref = scope.$("Fetch data");
    assert.strictEqual(ref.item.json.name, "");
    assert.strictEqual(ref.first().json.name, "");
    assert.strictEqual(ref.last().json.name, "");
    assert.strictEqual(ref.itemMatching(0).json.name, "");
    assert.strictEqual(ref.pairedItem().json.name, "");
    assert.strictEqual(ref.all()[0].json.name, "");
  });

  test("$() returns empty structure for unknown nodes", function (assert) {
    const ref = buildScope({}).$("Missing");
    assert.deepEqual(Object.keys(ref.item.json), []);
  });

  test("builds $vars from workflowVars", function (assert) {
    const scope = buildScope({
      workflowVars: [
        { key: "API_KEY", value: "secret" },
        { key: "URL", value: "https://example.com" },
      ],
    });

    assert.strictEqual(scope.$vars.API_KEY, "secret");
    assert.strictEqual(scope.$vars.URL, "https://example.com");
  });

  test("builds $execution with standard fields", function (assert) {
    const scope = buildScope({});

    assert.strictEqual(scope.$execution.id, 0);
    assert.strictEqual(scope.$execution.workflow_id, 0);
    assert.strictEqual(scope.$execution.workflow_name, "");
  });

  test("includes resume_url when a webhook wait node exists", function (assert) {
    const scope = buildScope({
      nodes: [{ type: "flow:wait", configuration: { resume: "webhook" } }],
    });

    assert.strictEqual(scope.$execution.resume_url, "");
  });

  test("omits resume_url when no webhook wait", function (assert) {
    assert.strictEqual(
      buildScope({ nodes: [] }).$execution.resume_url,
      undefined
    );
  });

  test("includes resumeFormUrl when a form page node exists", function (assert) {
    const scope = buildScope({
      nodes: [{ type: "action:form", configuration: { page_type: "page" } }],
    });

    assert.strictEqual(scope.$execution.resumeFormUrl, "");
  });

  test("omits resumeFormUrl when no form page node exists", function (assert) {
    const scope = buildScope({
      nodes: [
        { type: "action:form", configuration: { page_type: "completion" } },
      ],
    });

    assert.strictEqual(scope.$execution.resumeFormUrl, undefined);
  });

  test("exposes global constructors", function (assert) {
    const scope = buildScope({});

    assert.strictEqual(scope.Math, Math);
    assert.strictEqual(scope.JSON, JSON);
    assert.strictEqual(scope.parseInt, parseInt);
  });

  test("builds $current_user with id and username", function (assert) {
    const scope = buildScope({});

    assert.strictEqual(scope.$current_user.id, 0);
    assert.strictEqual(scope.$current_user.username, "");
  });

  test("filters private/theme keys from siteSettings", function (assert) {
    const scope = buildScope({
      siteSettings: {
        title: "My Forum",
        _internal: "hidden",
        theme_key: "skip",
        max_users: 100,
      },
    });

    assert.strictEqual(scope.$site_settings.title, "My Forum");
    assert.strictEqual(scope.$site_settings.max_users, 100);
    assert.strictEqual(scope.$site_settings._internal, undefined);
    assert.strictEqual(scope.$site_settings.theme_key, undefined);
  });

  test("maps boolean and array field types", function (assert) {
    const scope = buildScope({
      inputFields: [
        { key: "active", type: "boolean" },
        { key: "items", type: "array" },
      ],
    });

    assert.false(scope.$json.active);
    assert.deepEqual(scope.$json.items, []);
  });

  test("maps unknown field types to string exemplar", function (assert) {
    const scope = buildScope({
      inputFields: [{ key: "custom", type: "unknown_type" }],
    });

    assert.strictEqual(scope.$json.custom, "");
  });
});

module("Unit | lib | discourse-workflows | walkScope", function () {
  test("resolves top-level scope key", function (assert) {
    assert.deepEqual(walkScope({ $json: { title: "hello" } }, "$json"), {
      title: "hello",
    });
  });

  test("resolves nested dot path", function (assert) {
    assert.strictEqual(
      walkScope({ $json: { post: { id: 42 } } }, "$json.post.id"),
      42
    );
  });

  test("returns undefined for missing path", function (assert) {
    assert.strictEqual(
      walkScope({ $json: {} }, "$json.missing.deep"),
      undefined
    );
  });

  test("returns undefined for null path", function (assert) {
    assert.strictEqual(walkScope({}, null), undefined);
  });

  test("returns undefined for empty path", function (assert) {
    assert.strictEqual(walkScope({}, ""), undefined);
  });

  test("resolves node reference via $() path", function (assert) {
    const scope = {
      $: (name) => ({ item: { json: { name: `node-${name}` } } }),
    };

    assert.strictEqual(
      walkScope(scope, "$('MyNode').item.json.name"),
      "node-MyNode"
    );
  });

  test("resolves node reference method calls via $() path", function (assert) {
    const scope = {
      $itemIndex: 0,
      $: (name) => ({
        first: () => ({ json: { name: `node-${name}` } }),
        itemMatching: (index) => ({ json: { index } }),
        all: (branchIndex, runIndex) => [{ json: { branchIndex, runIndex } }],
      }),
    };

    assert.strictEqual(
      walkScope(scope, "$('MyNode').first().json.name"),
      "node-MyNode"
    );
    assert.strictEqual(
      walkScope(scope, "$('MyNode').itemMatching(2).json.index"),
      2
    );
    assert.deepEqual(walkScope(scope, "$('MyNode').all(1, 0)"), [
      { json: { branchIndex: 1, runIndex: 0 } },
    ]);
    assert.strictEqual(
      walkScope(scope, "$('MyNode').all(1)[$itemIndex].json.branchIndex"),
      1
    );
  });

  test("resolves node reference with double quotes", function (assert) {
    const scope = {
      $: (name) => ({ item: { json: { name: `node-${name}` } } }),
    };

    assert.strictEqual(
      walkScope(scope, '$("MyNode").item.json.name'),
      "node-MyNode"
    );
  });

  test("resolves escaped node references", function (assert) {
    const scope = {
      $: (name) => ({ item: { json: { name: `node-${name}` } } }),
    };

    assert.strictEqual(
      walkScope(scope, '$("Fetch \\"quoted\\" \\\\ data").item.json.name'),
      'node-Fetch "quoted" \\ data'
    );
    assert.strictEqual(
      walkScope(scope, "$('Fetch \\'quoted\\' \\\\ data').item.json.name"),
      "node-Fetch 'quoted' \\ data"
    );
  });

  test("returns undefined when $() throws for unknown node", function (assert) {
    const scope = {
      $: () => {
        throw new Error("not found");
      },
    };

    assert.strictEqual(walkScope(scope, "$('Missing').item"), undefined);
  });

  test("resolves array values", function (assert) {
    assert.deepEqual(walkScope({ $json: { tags: ["a", "b"] } }, "$json.tags"), [
      "a",
      "b",
    ]);
  });

  test("resolves array subscripts and bracket keys", function (assert) {
    const scope = {
      $json: { items: [{ id: 7 }, { id: 9 }], "weird key": "found" },
    };
    // Subscript on a nested property (the common array-index case).
    assert.strictEqual(walkScope(scope, "$json.items[0].id"), 7);
    assert.strictEqual(walkScope(scope, "$json.items[1].id"), 9);
    // Bracket key on the root token.
    assert.strictEqual(walkScope(scope, '$json["weird key"]'), "found");
    // Known limitation: a bracket key containing a dot is split by the path
    // parser, so it does not resolve (would need a bracket-aware tokenizer).
    assert.strictEqual(
      walkScope({ $json: { "a.b": 1 } }, '$json["a.b"]'),
      undefined
    );
  });

  test("resolves boolean values", function (assert) {
    assert.true(walkScope({ $json: { active: true } }, "$json.active"));
  });

  test("stops at null intermediate", function (assert) {
    assert.strictEqual(
      walkScope({ $json: { post: null } }, "$json.post.id"),
      undefined
    );
  });

  test("handles node ref with no further path", function (assert) {
    const nodeData = { item: { json: { id: 1 } } };
    assert.deepEqual(walkScope({ $: () => nodeData }, "$('Node')"), nodeData);
  });
});

module("Unit | lib | discourse-workflows | resolveVariableId", function () {
  test("keeps dollar-prefixed IDs as-is", function (assert) {
    assert.strictEqual(
      resolveVariableId({ id: "$current_user.username" }),
      "$current_user.username"
    );
  });

  test("prepends $json to non-dollar IDs", function (assert) {
    assert.strictEqual(resolveVariableId({ id: "topic_id" }), "$json.topic_id");
  });

  test("uses custom itemPrefix", function (assert) {
    assert.strictEqual(
      resolveVariableId({ id: "topic_id" }, "$item"),
      "$item.topic_id"
    );
  });
});
