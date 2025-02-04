import { htmlSafe } from "@ember/template";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { emojiUnescape } from "discourse/lib/text";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import { createRenderDirector } from "discourse/tests/helpers/reviewable-types-helper";
import { i18n } from "discourse-i18n";

function getReviewable(overrides = {}) {
  return UserMenuReviewable.create(
    Object.assign(
      {
        flagger_username: "sayo2",
        id: 17,
        pending: false,
        type: "ReviewableFlaggedPost",
        topic_fancy_title: "anything hello world",
        post_number: 1,
      },
      overrides
    )
  );
}

module("Unit | Reviewable Items | flagged-post", function (hooks) {
  setupTest(hooks);

  test("description", function (assert) {
    const reviewable = getReviewable({
      topic_fancy_title: "This is safe title &lt;a&gt; :heart:",
    });
    const director = createRenderDirector(
      reviewable,
      "ReviewableFlaggedPost",
      this.siteSettings
    );
    assert.deepEqual(
      director.description,
      htmlSafe(
        i18n("user_menu.reviewable.post_number_with_topic_title", {
          title: `This is safe title &lt;a&gt; ${emojiUnescape(":heart:")}`,
          post_number: 1,
        })
      ),
      "contains the fancy title without escaping because it's already safe"
    );

    delete reviewable.topic_fancy_title;
    delete reviewable.post_number;
    assert.deepEqual(
      director.description,
      i18n("user_menu.reviewable.deleted_post"),
      "falls back to generic string when the post/topic is deleted"
    );
  });
});
