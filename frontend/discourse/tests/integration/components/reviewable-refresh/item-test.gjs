import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableItemRefresh from "discourse/components/reviewable-refresh/item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | reviewable-refresh | item", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(function () {
    this.siteSettings.moderation_guide_url =
      "https://example.com/moderation_guide";
    this.siteSettings.flag_priorities_url =
      "https://example.com/flag_priorities";
    this.siteSettings.spam_detection_url = "https://example.com/spam_detection";
  });

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
    type: "topic",
    reviewable_scores: [],
    target_created_by: {
      id: 1,
      username: "testuser",
      name: "Test User",
      flags_agreed: 0,
    },
  };

  test("renders help resources ", async function (assert) {
    await render(
      <template>
        <ReviewableItemRefresh @reviewable={{reviewable}} @showHelp={{true}} />
      </template>
    );
    assert.dom(".review-item__resources").exists("renders the help content");
    assert
      .dom(
        `a.review-resources__link[href="https://example.com/moderation_guide"]`
      )
      .exists();
    assert
      .dom(
        `a.review-resources__link[href="https://example.com/flag_priorities"]`
      )
      .exists();
    assert
      .dom(
        `a.review-resources__link[href="https://example.com/spam_detection"]`
      )
      .exists();
  });

  test("does not render help resources when not required", async function (assert) {
    await render(
      <template><ReviewableItemRefresh @reviewable={{reviewable}} /></template>
    );
    assert
      .dom(".review-item__resources")
      .doesNotExist("does not render the help content");
  });
});
