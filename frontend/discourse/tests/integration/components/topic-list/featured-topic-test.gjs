import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FeaturedTopic from "discourse/components/topic-list/featured-topic";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const EventBadgeStub = <template>
  {{#if @outletArgs.topic.event_starts_at}}
    <span class="event-date test-badge">in 14 hours</span>
  {{/if}}
</template>;

module("Integration | Component | FeaturedTopic", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    withPluginApi((api) => {
      api.renderInOutlet("topic-list-after-title", EventBadgeStub);
    });
  });

  test("renders the topic-list-after-title connector (event badge) for event topics", async function (assert) {
    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", {
      id: 1234,
      title: "My event topic",
      event_starts_at: "2026-06-01T10:00:00.000Z",
    });

    await render(<template><FeaturedTopic @topic={{topic}} /></template>);

    assert
      .dom(".featured-topic .event-date.test-badge")
      .exists("renders the event badge after the topic title");
  });
});
