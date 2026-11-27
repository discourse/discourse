import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TopicNavigation from "discourse/components/topic-navigation";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer from "discourse/models/composer";
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

  test("hands over the latest scroll event without re-rendering on scroll", async function (assert) {
    forceMobile();
    const topic = this.topic;
    const appEvents = this.owner.lookup("service:app-events");

    await render(
      <template>
        <TopicNavigation @topic={{topic}} as |info|>
          <span class="scrolled-post">{{info.prevEvent.postIndex}}</span>
        </TopicNavigation>
      </template>
    );

    appEvents.trigger("topic:current-post-scrolled", {
      postIndex: 4,
      percent: 0.6,
    });
    await settled();

    assert
      .dom(".scrolled-post")
      .hasNoText("scrolling does not invalidate the yielded block");

    appEvents.trigger("topic:toggle-progress-expansion");
    await settled();

    assert
      .dom(".scrolled-post")
      .hasText("4", "switching to the timeline reads the latest event");
  });

  module("short desktop viewport", function (viewportHooks) {
    viewportHooks.beforeEach(function () {
      this.matchMedia = sinon.stub(window, "matchMedia").callsFake((query) => {
        const matcher = new EventTarget();
        matcher.matches = query.startsWith("(min-width:");
        return matcher;
      });
      this.currentUser.set(
        "user_option.composition_mode",
        USER_OPTION_COMPOSITION_MODES.markdown
      );
      this.composer = this.owner.lookup("service:composer");
      this.composer.showPreview = true;
    });

    viewportHooks.afterEach(function () {
      this.matchMedia.restore();
    });

    test("the preview constrains the timeline only while the composer is visible", async function (assert) {
      const topic = this.topic;

      await render(<template><TopicNavigation @topic={{topic}} /></template>);

      assert.true(
        this.composer.isPreviewVisible,
        "the composer predicts its preview width before opening"
      );
      assert
        .dom(".with-timeline")
        .exists("a closed composer does not take space from the timeline");

      this.composer.set(
        "model",
        this.owner.lookup("service:store").createRecord("composer", {
          action: Composer.CREATE_TOPIC,
          composeState: Composer.OPEN,
        })
      );
      await settled();

      assert
        .dom(".with-topic-progress")
        .exists("an open preview leaves insufficient room for the timeline");

      this.composer.close();
      await settled();

      assert
        .dom(".with-timeline")
        .exists("closing restores the timeline despite the predicted preview");
    });
  });
});
