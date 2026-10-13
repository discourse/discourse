import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  buildColumnComponents,
  buildRelationTables,
  displayColumnNames,
  relationLabel,
  VIEW_COMPONENTS,
} from "../../discourse/lib/result-columns";

module("Unit | Lib | result-columns", function (hooks) {
  setupTest(hooks);

  test("displayColumnNames strips id suffixes and type prefixes", function (assert) {
    assert.deepEqual(
      displayColumnNames(["topic_id", "topic$latest", "count"]),
      ["topic", "latest", "count"],
      "keeps plain names untouched"
    );
  });

  test("displayColumnNames handles missing columns", function (assert) {
    assert.deepEqual(
      displayColumnNames(undefined),
      [],
      "returns an empty list"
    );
  });

  test("relationLabel prefers username, then title, then name", function (assert) {
    assert.strictEqual(relationLabel({ username: "u", title: "t" }), "u");
    assert.strictEqual(relationLabel({ title: "t", name: "n" }), "t");
    assert.strictEqual(relationLabel({ name: "n" }), "n");
    assert.strictEqual(relationLabel(undefined), undefined);
  });

  test("buildRelationTables seeds categories and groups from the site", function (assert) {
    const site = this.owner.lookup("service:site");
    const tables = buildRelationTables(
      { topic: [{ id: 7, title: "Seven" }], category: [] },
      site
    );

    assert.strictEqual(tables.category[3].name, "meta", "uses site categories");
    assert.strictEqual(tables.group[1].name, "admins", "uses site groups");
    assert.strictEqual(
      tables.topic[7].title,
      "Seven",
      "indexes relations by id"
    );
  });

  test("buildColumnComponents maps colrender types to components", function (assert) {
    const content = {
      columns: ["topic_id", "count"],
      colrender: { 0: "topic" },
      hidden_relations: { topic: [42] },
    };
    const tables = { topic: { 7: { id: 7 } } };

    const [topic, count] = buildColumnComponents(content, tables);

    assert.strictEqual(topic.name, "topic");
    assert.strictEqual(topic.component, VIEW_COMPONENTS.topic);
    assert.strictEqual(topic.table, tables.topic);
    assert.deepEqual(topic.hidden, [42]);
    assert.strictEqual(count.name, "text");
    assert.strictEqual(count.table, undefined);
  });

  test("buildColumnComponents falls back to text for types outside the view map", function (assert) {
    const content = {
      columns: ["post_id"],
      colrender: { 0: "post" },
    };
    const tables = { post: { 1: { id: 1 } } };

    const [post] = buildColumnComponents(content, tables, {
      text: VIEW_COMPONENTS.text,
      topic: VIEW_COMPONENTS.topic,
    });

    assert.strictEqual(post.name, "text", "treats the column as text");
    assert.strictEqual(post.table, undefined, "does not attach a lookup table");
  });

  test("buildColumnComponents handles a payload without columns", function (assert) {
    assert.deepEqual(buildColumnComponents(undefined, {}), []);
  });
});
