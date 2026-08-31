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

    test("a predicted preview does not constrain the timeline while closed", async function (assert) {
      const topic = this.topic;

      await render(<template><TopicNavigation @topic={{topic}} /></template>);

      assert.true(
        this.composer.isPreviewVisible,
        "the composer predicts its preview width before opening"
      );
      assert
        .dom(".with-timeline")
        .exists("a closed composer does not take space from the timeline");
    });

    test("the preview constrains the timeline only while the composer is visible", async function (assert) {
      this.composer.set(
        "model",
        this.owner.lookup("service:store").createRecord("composer", {
          action: Composer.CREATE_TOPIC,
          composeState: Composer.OPEN,
        })
      );
      const topic = this.topic;

      await render(<template><TopicNavigation @topic={{topic}} /></template>);

      assert
        .dom(".with-topic-progress")
        .exists("an open preview leaves insufficient room for the timeline");

      this.composer.showPreview = false;
      await settled();

      assert
        .dom(".with-timeline")
        .exists("hiding the preview restores the timeline");

      this.composer.showPreview = true;
      await settled();

      assert
        .dom(".with-topic-progress")
        .exists("showing the preview constrains the timeline again");

      this.composer.close();
      await settled();

      assert
        .dom(".with-timeline")
        .exists("closing restores the timeline despite the predicted preview");
    });
  });
});
