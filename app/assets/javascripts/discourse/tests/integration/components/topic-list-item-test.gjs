import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicListItem from "discourse/components/topic-list/item";
import TopicList from "discourse/components/topic-list/list";
import HbrTopicListItem from "discourse/components/topic-list-item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("checkbox is rendered checked if topic is in selected array", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", { id: 24234 });
    const topic2 = store.createRecord("topic", { id: 24235 });
    const selected = [topic];

    await render(<template>
      <HbrTopicListItem
        @topic={{topic}}
        @bulkSelectEnabled={{true}}
        @selected={{selected}}
      />
      <HbrTopicListItem
        @topic={{topic2}}
        @bulkSelectEnabled={{true}}
        @selected={{selected}}
      />
    </template>);

    const checkboxes = [...document.querySelectorAll("input.bulk-select")];
    assert.dom(checkboxes[0]).isChecked();
    assert.dom(checkboxes[1]).isNotChecked();
  });

  test("topic-list-item-class value transformer", async function (assert) {
    withPluginApi("1.39.0", (api) => {
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
    const topic = store.createRecord("topic", { id: 1234, foo: true });
    const topic2 = store.createRecord("topic", { id: 1235, foo: false });
    await render(<template>
      <TopicListItem @topic={{topic}} />
      <TopicListItem @topic={{topic2}} />
    </template>);

    assert.dom(".topic-list-item[data-topic-id='1234']").hasClass("bar");
    assert
      .dom(".topic-list-item[data-topic-id='1235']")
      .doesNotHaveClass("bar");
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
