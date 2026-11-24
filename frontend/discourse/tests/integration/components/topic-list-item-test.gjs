import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicList from "discourse/components/topic-list/list";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | TopicListItem", function (hooks) {
  setupRenderingTest(hooks);

  test("checkbox is rendered checked if topic is in selected array", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topics = [
      store.createRecord("topic", { id: 24234 }),
      store.createRecord("topic", { id: 24235 }),
    ];

    const bulkSelectHelper = new BulkSelectHelper(this);
    bulkSelectHelper.toggleBulkSelect();
    bulkSelectHelper.selected.push(topics[0]);

    await render(
      <template>
        <TopicList
          @bulkSelectHelper={{bulkSelectHelper}}
          @canBulkSelect={{true}}
          @topics={{topics}}
        />
      </template>
    );

    const checkboxes = [...document.querySelectorAll("input.bulk-select")];
    assert.dom(checkboxes[0]).isChecked();
    assert.dom(checkboxes[1]).isNotChecked();
  });

  test("a row has a spoken name that follows what the row shows", async function (assert) {
    const store = this.owner.lookup("service:store");
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    const topics = [
      store.createRecord("topic", {
        id: 7001,
        title: "Welcome to the forum",
        unseen: true,
        closed: true,
        pinned: true,
        tags: ["alpha", "beta"],
        posts_count: 4,
        views: 120,
        created_at: threeDaysAgo.toISOString(),
        bumped_at: threeDaysAgo.toISOString(),
      }),
      store.createRecord("topic", {
        id: 7002,
        title: "A quiet topic",
        unread_posts: 2,
        posts_count: 2,
        views: 1,
        created_at: threeDaysAgo.toISOString(),
        bumped_at: threeDaysAgo.toISOString(),
      }),
    ];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert
      .dom(".topic-list-item[data-topic-id='7001']")
      .hasAttribute(
        "aria-label",
        "New, Welcome to the forum, Closed, Pinned, Tags: alpha, beta, 3 replies, 120 views, Last activity 3 days ago",
        "says new first, then the title, status, tags, counts and activity"
      );

    assert
      .dom(".topic-list-item[data-topic-id='7002']")
      .hasAttribute(
        "aria-label",
        "2 new replies, A quiet topic, 1 reply, 1 view, Last activity 3 days ago",
        "says the new replies first, and uses the singular forms"
      );
  });

  test("a pinned topic's preview is said last, as plain text", async function (assert) {
    const store = this.owner.lookup("service:store");
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    const topics = [
      store.createRecord("topic", {
        id: 7003,
        title: "A pinned topic",
        pinned: true,
        excerpt: "Please <b>pass</b>   the salt &hellip;",
        posts_count: 2,
        views: 5,
        created_at: threeDaysAgo.toISOString(),
        bumped_at: threeDaysAgo.toISOString(),
      }),
    ];

    await render(
      <template>
        <TopicList @expandAllPinned={{true}} @topics={{topics}} />
      </template>
    );

    assert
      .dom(".topic-list-item[data-topic-id='7003']")
      .hasAttribute(
        "aria-label",
        "A pinned topic, Pinned, 1 reply, 5 views, Last activity 3 days ago, Please pass the salt …",
        "says the preview last, as plain text with the spaces collapsed"
      );
  });

  test("topic-list-item-class value transformer", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          if (context.topic.get("foo")) {
            value.push("bar");
          }
          return value;
        }
      );
    });

    const store = this.owner.lookup("service:store");
    const topics = [
      store.createRecord("topic", { id: 1234, foo: true }),
      store.createRecord("topic", { id: 1235, foo: false }),
    ];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert.dom(".topic-list-item[data-topic-id='1234']").hasClass("bar");
    assert
      .dom(".topic-list-item[data-topic-id='1235']")
      .doesNotHaveClass("bar");
  });

  test("topic-list-item-class transformer receives category context", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          value.push(`cat-${context.category?.id ?? "none"}`);
          return value;
        }
      );
    });

    const store = this.owner.lookup("service:store");
    this.owner.lookup("service:topic-tracking-state").filterCategory =
      store.createRecord("category", { id: 42 });
    const topics = [store.createRecord("topic", { id: 2024 })];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert.dom(".topic-list-item[data-topic-id='2024']").hasClass("cat-42");
  });

  test("shows unread-by-group-member indicator", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topics = [
      store.createRecord("topic", { id: 1234 }),
      store.createRecord("topic", {
        id: 1235,
        unread_by_group_member: true,
      }),
      store.createRecord("topic", {
        id: 1236,
        unread_by_group_member: false,
      }),
    ];

    await render(<template><TopicList @topics={{topics}} /></template>);

    assert
      .dom(".badge.badge-notification.unread-indicator")
      .exists({ count: 1 });
    assert
      .dom(".topic-list-item[data-topic-id='1235'] .unread-indicator")
      .exists();
  });
});
