import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | reviewable-refresh | topic-link",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders topic information when topic exists", async function (assert) {
      const reviewable = {
        topic: {
          fancyTitle: "Test Topic Title",
          id: 123,
        },
        target_url: "/t/test-topic/123",
        category: {
          id: 5,
          name: "General",
          color: "0088CC",
        },
        topic_tags: ["tag1", "tag2"],
      };

      await render(
        <template>
          <ReviewableTopicLink @reviewable={{reviewable}}><span
              class="custom-fallback"
            >Custom fallback content</span></ReviewableTopicLink>
        </template>
      );

      assert.dom(".topic-statuses").exists("renders the TopicStatus component");

      assert.dom("a.title-text").exists("renders the topic title link");
      assert
        .dom("a.title-text")
        .hasAttribute("href", "/t/test-topic/123", "has correct target URL");
      assert
        .dom("a.title-text")
        .containsText("Test Topic Title", "displays the topic title");

      assert.dom(".badge-category").exists("renders the category badge");
      assert.dom(".list-tags").exists("renders the ReviewableTags component");

      assert
        .dom(".custom-fallback")
        .doesNotExist("doesn't render the block content");
    });

    test("renders deleted topic message when topic does not exist", async function (assert) {
      const reviewable = {
        removed_topic_id: 999,
      };

      await render(
        <template><ReviewableTopicLink @reviewable={{reviewable}} /></template>
      );

      assert.dom("span.title-text").exists("renders the title text span");
      assert
        .dom("span.title-text")
        .containsText("[Topic Deleted]", "shows deleted topic message");
      assert.dom("span.title-text a").exists("renders link to original topic");
      assert
        .dom("span.title-text a")
        .containsText("original topic", "shows original topic link text");
    });

    test("renders block content when topic is missing and block is provided", async function (assert) {
      const reviewable = {};

      await render(
        <template>
          <ReviewableTopicLink @reviewable={{reviewable}}>
            <span class="custom-fallback">Custom fallback content</span>
          </ReviewableTopicLink>
        </template>
      );

      assert.dom(".custom-fallback").exists("renders the block content");
      assert
        .dom(".custom-fallback")
        .containsText("Custom fallback content", "displays block content text");
      assert
        .dom(".title-text")
        .doesNotExist("does not render default deleted topic message");
    });
  }
);
