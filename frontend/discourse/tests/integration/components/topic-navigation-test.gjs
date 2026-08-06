import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicNavigation from "discourse/components/topic-navigation";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | TopicNavigation", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.topic = this.owner
      .lookup("service:store")
      .createRecord("topic", { id: 1234, posts_count: 5 });
  });

  test("renders the progress bar when there is no room for the timeline", async function (assert) {
    forceMobile();
    const topic = this.topic;

    await render(
      <template>
        <TopicNavigation @topic={{topic}} as |info|>
          <span class="render-timeline">{{info.renderTimeline}}</span>
        </TopicNavigation>
      </template>
    );

    assert.dom(".render-timeline").hasText("false");
    assert.dom(".with-topic-progress").exists();
  });

  test("topic-navigation-render-timeline value transformer", async function (assert) {
    forceMobile();
    withPluginApi((api) => {
      api.registerValueTransformer(
        "topic-navigation-render-timeline",
        ({ context }) => context.topic.id === 1234
      );
    });
    const topic = this.topic;

    await render(
      <template>
        <TopicNavigation @topic={{topic}} as |info|>
          <span class="render-timeline">{{info.renderTimeline}}</span>
        </TopicNavigation>
      </template>
    );

    assert.dom(".render-timeline").hasText("true");
    assert.dom(".with-timeline").exists();
  });
});
