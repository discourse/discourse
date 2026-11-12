import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | LatestTopicListItem", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    withPluginApi((api) => {
      api.renderInOutlet(
        "topic-list-after-title",
        <template>
          {{#if @outletArgs.topic.event_starts_at}}
            <span class="event-date test-badge">in 14 hours</span>
          {{/if}}
        </template>
      );
    });
  });

  test("latest-topic-list-item-class value transformer", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "latest-topic-list-item-class",
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
    await render(
      <template>
        <LatestTopicListItem @topic={{topic}} />
        <LatestTopicListItem @topic={{topic2}} />
      </template>
    );

    assert.dom(".latest-topic-list-item[data-topic-id='1234']").hasClass("bar");
    assert
      .dom(".latest-topic-list-item[data-topic-id='1235']")
      .doesNotHaveClass("bar");
  });

  test("renders the topic-list-after-title connector (event badge) for event topics", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 1234,
      title: "My event topic",
      event_starts_at: "2026-06-01T10:00:00.000Z",
    });

    await render(<template><LatestTopicListItem @topic={{topic}} /></template>);

    assert
      .dom(".latest-topic-list-item .event-date.test-badge")
      .exists("renders the event badge after the topic title");
  });
});
