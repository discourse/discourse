import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-list", function (hooks) {
  setupRenderingTest(hooks);

  test("bulk select", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    this.setProperties({
      topics: [
        store.createRecord("topic", { id: 24234 }),
        store.createRecord("topic", { id: 24235 }),
      ],
      bulkSelectHelper: new BulkSelectHelper(this),
    });

    await render(hbs`
      <TopicList
        @canBulkSelect={{true}}
        @bulkSelectHelper={{this.bulkSelectHelper}}
        @topics={{this.topics}}
      />
    `);

    assert.strictEqual(
      this.bulkSelectHelper.selected.length,
      0,
      "defaults to 0"
    );
    await click("button.bulk-select");
    assert.true(
      this.bulkSelectHelper.bulkSelectEnabled,
      "bulk select is enabled"
    );

    await click("button.bulk-select-all");
    assert.strictEqual(
      this.bulkSelectHelper.selected.length,
      2,
      "clicking Select All selects all loaded topics"
    );
    assert.true(
      this.bulkSelectHelper.autoAddTopicsToBulkSelect,
      "clicking Select All turns on the autoAddTopicsToBulkSelect flag"
    );

    await click("button.bulk-clear-all");
    assert.strictEqual(
      this.bulkSelectHelper.selected.length,
      0,
      "clicking Clear All deselects all topics"
    );
    assert.false(
      this.bulkSelectHelper.autoAddTopicsToBulkSelect,
      "clicking Clear All turns off the autoAddTopicsToBulkSelect flag"
    );
  });
});
