import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import Topic from "discourse/models/topic";
import hbs from "htmlbars-inline-precompile";

module("Integration | Component | topic-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("checkbox is rendered checked if topic is in selected array", async function (assert) {
    const topic = Topic.create({ id: 24234 });
    const topic2 = Topic.create({ id: 24235 });
    this.setProperties({
      topic,
      topic2,
      selected: [topic],
    });

    await render(hbs`
      <TopicListItem
        @topic={{this.topic}}
        @bulkSelectEnabled={{true}}
        @selected={{this.selected}}
      />
      <TopicListItem
        @topic={{this.topic2}}
        @bulkSelectEnabled={{true}}
        @selected={{this.selected}}
      />
    `);

    const checkboxes = queryAll("input.bulk-select");
    assert.ok(checkboxes[0].checked);
    assert.ok(!checkboxes[1].checked);
  });
});
