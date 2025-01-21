import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import HbrTopicList from "discourse/components/topic-list";
import TopicList from "discourse/components/topic-list/list";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-list", function (hooks) {
  setupRenderingTest(hooks);

  test("bulk select", async function (assert) {
    const bulkSelectHelper = new BulkSelectHelper(this);
    const store = getOwner(this).lookup("service:store");
    const topics = [
      store.createRecord("topic", { id: 24234 }),
      store.createRecord("topic", { id: 24235 }),
    ];

    await render(<template>
      <HbrTopicList
        @canBulkSelect={{true}}
        @bulkSelectHelper={{bulkSelectHelper}}
        @topics={{topics}}
      />
    </template>);

    assert.strictEqual(bulkSelectHelper.selected.length, 0, "defaults to 0");

    await click("button.bulk-select");
    assert.true(bulkSelectHelper.bulkSelectEnabled, "bulk select is enabled");

    await click("button.bulk-select-all");
    assert.strictEqual(
      bulkSelectHelper.selected.length,
      2,
      "clicking Select All selects all loaded topics"
    );
    assert.true(
      bulkSelectHelper.autoAddTopicsToBulkSelect,
      "clicking Select All turns on the autoAddTopicsToBulkSelect flag"
    );

    await click("button.bulk-clear-all");
    assert.strictEqual(
      bulkSelectHelper.selected.length,
      0,
      "clicking Clear All deselects all topics"
    );
    assert.false(
      bulkSelectHelper.autoAddTopicsToBulkSelect,
      "clicking Clear All turns off the autoAddTopicsToBulkSelect flag"
    );
  });

  test("renders a list of all-pinned topics", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.set("previous_visit_at", +new Date());
    const store = getOwner(this).lookup("service:store");
    const topics = [
      store.createRecord("topic", { id: 24234, pinned: true }),
      store.createRecord("topic", { id: 24235, pinned: true }),
    ];

    await render(<template>
      <TopicList @topics={{topics}} @highlightLastVisited={{true}} />
    </template>);

    assert.dom(".topic-status .d-icon-thumbtack").exists({ count: 2 });
  });
});
