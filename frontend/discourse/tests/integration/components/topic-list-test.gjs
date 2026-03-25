import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicList from "discourse/components/topic-list/list";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { withPluginApi } from "discourse/lib/plugin-api";
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

    await render(
      <template>
        <TopicList
          @canBulkSelect={{true}}
          @bulkSelectHelper={{bulkSelectHelper}}
          @topics={{topics}}
        />
      </template>
    );

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

    await render(
      <template>
        <TopicList @topics={{topics}} @highlightLastVisited={{true}} />
      </template>
    );

    assert.dom(".topic-status .d-icon-thumbtack").exists({ count: 2 });
  });

  test("topic-list-columns transformer receives context with category and filter", async function (assert) {
    let receivedContext;

    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-columns",
        ({ value, context }) => {
          receivedContext = context;
          return value;
        }
      );
    });

    const store = getOwner(this).lookup("service:store");
    const topicTrackingState = getOwner(this).lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.filterCategory = { id: 42, name: "test" };
    topicTrackingState.filter = "latest";

    const topics = [store.createRecord("topic", { id: 24234 })];

    await render(
      <template>
        <TopicList @topics={{topics}} @listContext="test-context" />
      </template>
    );

    assert.strictEqual(
      receivedContext.category?.id,
      42,
      "context includes the filter category"
    );
    assert.strictEqual(
      receivedContext.filter,
      "latest",
      "context includes the filter"
    );
    assert.strictEqual(
      receivedContext.listContext,
      "test-context",
      "context includes the listContext"
    );
  });

  test("topic-list-class transformer receives context with category and filter", async function (assert) {
    let receivedContext;

    withPluginApi((api) => {
      api.registerValueTransformer("topic-list-class", ({ value, context }) => {
        receivedContext = context;
        return value;
      });
    });

    const store = getOwner(this).lookup("service:store");
    const topicTrackingState = getOwner(this).lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.filterCategory = { id: 99, name: "docs" };
    topicTrackingState.filter = "top";

    const topics = [store.createRecord("topic", { id: 24234 })];

    await render(
      <template>
        <TopicList @topics={{topics}} @listContext="other-context" />
      </template>
    );

    assert.strictEqual(
      receivedContext.category?.id,
      99,
      "context includes the filter category"
    );
    assert.strictEqual(
      receivedContext.filter,
      "top",
      "context includes the filter"
    );
    assert.strictEqual(
      receivedContext.listContext,
      "other-context",
      "context includes the listContext"
    );
  });

  test("topic-list-columns transformer can remove columns", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-columns",
        ({ value: columns }) => {
          columns.delete("views");
          return columns;
        }
      );
    });

    const store = getOwner(this).lookup("service:store");
    const topics = [store.createRecord("topic", { id: 24234 })];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert
      .dom(".topic-list th[data-sort-order='views']")
      .doesNotExist("views column is removed");
    assert
      .dom(".topic-list th[data-sort-order='posts']")
      .exists("replies column remains");
    assert
      .dom(".topic-list th[data-sort-order='activity']")
      .exists("activity column remains");
  });

  test("topic-list-class transformer can add classes", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("topic-list-class", ({ value: classes }) => {
        classes.push("custom-class");
        return classes;
      });
    });

    const store = getOwner(this).lookup("service:store");
    const topics = [store.createRecord("topic", { id: 24234 })];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert.dom("table.topic-list.custom-class").exists("custom class is added");
  });
});
