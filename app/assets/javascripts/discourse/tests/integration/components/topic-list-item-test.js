import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("checkbox is rendered checked if topic is in selected array", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 24234 });
    const topic2 = store.createRecord("topic", { id: 24235 });
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

    const checkboxes = [...document.querySelectorAll("input.bulk-select")];
    assert.dom(checkboxes[0]).isChecked();
    assert.dom(checkboxes[1]).isNotChecked();
  });
});
