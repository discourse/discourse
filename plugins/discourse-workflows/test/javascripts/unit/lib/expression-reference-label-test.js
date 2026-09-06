import { module, test } from "qunit";
import {
  parseReference,
  referenceLabel,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/reference-label";

module("Unit | lib | discourse-workflows | parseReference", function () {
  test("parses a node-reference field path", function (assert) {
    const parsed = parseReference(
      '$("Create Intermediate Topic").first().json.topic.id'
    );
    assert.deepEqual(parsed, {
      source: { type: "node", name: "Create Intermediate Topic" },
      path: "topic.id",
    });
  });

  test("parses node references using .item and a branch index", function (assert) {
    assert.deepEqual(parseReference("$('Fetch').item.json.user.name"), {
      source: { type: "node", name: "Fetch" },
      path: "user.name",
    });
    assert.deepEqual(parseReference('$("Split").first(1).json.value'), {
      source: { type: "node", name: "Split" },
      path: "value",
    });
  });

  test("parses current-input ($json / $input) references", function (assert) {
    assert.deepEqual(parseReference("$json.topic.id"), {
      source: { type: "input" },
      path: "topic.id",
    });
    assert.deepEqual(parseReference("$input.first().json.title"), {
      source: { type: "input" },
      path: "title",
    });
  });

  test("parses $trigger and $itemIndex as their own sources", function (assert) {
    assert.deepEqual(parseReference("$trigger.post.raw"), {
      source: { type: "trigger" },
      path: "post.raw",
    });
    assert.deepEqual(parseReference("$itemIndex"), {
      source: { type: "item_index" },
      path: "",
    });
  });

  test("parses the remaining dollar roots", function (assert) {
    assert.strictEqual(parseReference("$vars.api_key").source.type, "variable");
    assert.strictEqual(
      parseReference("$current_user.username").source.type,
      "current_user"
    );
    assert.strictEqual(
      parseReference("$site_settings.title").source.type,
      "site_setting"
    );
    assert.strictEqual(
      parseReference("$execution.id").source.type,
      "execution"
    );
  });

  test("supports bracket and numeric subscripts", function (assert) {
    assert.deepEqual(parseReference("$json.items[0].id"), {
      source: { type: "input" },
      path: "items[0].id",
    });
    assert.deepEqual(parseReference("$json['weird key'].value"), {
      source: { type: "input" },
      path: "['weird key'].value",
    });
  });

  test("allows bare references with no trailing path", function (assert) {
    assert.deepEqual(parseReference("$json"), {
      source: { type: "input" },
      path: "",
    });
  });

  test("rejects anything that isn't a plain reference", function (assert) {
    assert.strictEqual(parseReference("$json.a + $json.b"), null);
    assert.strictEqual(parseReference("$json.count > 5"), null);
    assert.strictEqual(parseReference("Math.max($json.a, 1)"), null);
    assert.strictEqual(
      parseReference('$("Node").first().json.items.map(x)'),
      null
    );
    assert.strictEqual(parseReference("$json.title.toUpperCase()"), null);
    assert.strictEqual(parseReference(""), null);
    assert.strictEqual(parseReference("   "), null);
  });
});

module("Unit | lib | discourse-workflows | referenceLabel", function () {
  test("uses the node name as the badge for node references", function (assert) {
    const label = referenceLabel(
      parseReference('$("Create Topic").first().json.topic.id')
    );
    assert.strictEqual(label.sourceType, "node");
    assert.strictEqual(label.badge, "Create Topic");
    assert.strictEqual(label.path, "topic.id");
    assert.strictEqual(label.icon, "diagram-project");
  });

  test("labels $trigger and $itemIndex with their own source and icon", function (assert) {
    const trigger = referenceLabel(parseReference("$trigger.topic.id"));
    assert.strictEqual(trigger.sourceType, "trigger");
    assert.strictEqual(trigger.icon, "play");
    assert.strictEqual(trigger.path, "topic.id");

    const itemIndex = referenceLabel(parseReference("$itemIndex"));
    assert.strictEqual(itemIndex.sourceType, "item_index");
    assert.strictEqual(itemIndex.icon, "hashtag");
  });

  test("returns null for unparseable expressions", function (assert) {
    assert.strictEqual(referenceLabel(parseReference("$json.a + 1")), null);
  });
});
