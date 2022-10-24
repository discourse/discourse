import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import Topic from "discourse/models/topic";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | topic-list", function (hooks) {
  setupRenderingTest(hooks);

  test("bulk select", async function (assert) {
    this.setProperties({
      topics: [Topic.create({ id: 24234 }), Topic.create({ id: 24235 })],
      selected: [],
      bulkSelectEnabled: false,
      autoAddTopicsToBulkSelect: false,

      toggleBulkSelect() {
        this.toggleProperty("bulkSelectEnabled");
      },

      updateAutoAddTopicsToBulkSelect(newVal) {
        this.set("autoAddTopicsToBulkSelect", newVal);
      },
    });

    await render(hbs`
      <TopicList
        @canBulkSelect={{true}}
        @toggleBulkSelect={{this.toggleBulkSelect}}
        @bulkSelectEnabled={{this.bulkSelectEnabled}}
        @autoAddTopicsToBulkSelect={{this.autoAddTopicsToBulkSelect}}
        @updateAutoAddTopicsToBulkSelect={{this.updateAutoAddTopicsToBulkSelect}}
        @topics={{this.topics}}
        @selected={{this.selected}}
      />
    `);

    assert.strictEqual(this.selected.length, 0, "defaults to 0");
    await click("button.bulk-select");
    assert.ok(this.bulkSelectEnabled, "bulk select is enabled");

    await click("button.bulk-select-all");
    assert.strictEqual(
      this.selected.length,
      2,
      "clicking Select All selects all loaded topics"
    );
    assert.ok(
      this.autoAddTopicsToBulkSelect,
      "clicking Select All turns on the autoAddTopicsToBulkSelect flag"
    );

    await click("button.bulk-clear-all");
    assert.strictEqual(
      this.selected.length,
      0,
      "clicking Clear All deselects all topics"
    );
    assert.ok(
      !this.autoAddTopicsToBulkSelect,
      "clicking Clear All turns off the autoAddTopicsToBulkSelect flag"
    );
  });
});
