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
        topic_fancy_title: "anything hello world",
        type: "ReviewableQueuedPost",
      },
      overrides
    )
  );
}

module("Unit | Reviewable Items | queued-post", function (hooks) {
  setupTest(hooks);

  test("description", function (assert) {
    const reviewable = getReviewable({
      topic_fancy_title: "This is safe title &lt;a&gt; :heart:",
    });
    const director = createRenderDirector(
      reviewable,
      "ReviewableQueuedPost",
      this.siteSettings
    );
    assert.deepEqual(
      director.description,
      htmlSafe(
        i18n("user_menu.reviewable.new_post_in_topic", {
          title: `This is safe title &lt;a&gt; ${emojiUnescape(":heart:")}`,
        })
      ),
      "contains the fancy title without escaping because it's already safe"
    );

    delete reviewable.topic_fancy_title;
    reviewable.payload_title = "This is unsafe title <a> :heart:";
    assert.deepEqual(
      director.description,
      htmlSafe(
        i18n("user_menu.reviewable.new_post_in_topic", {
          title: `This is unsafe title &lt;a&gt; ${emojiUnescape(":heart:")}`,
        })
      ),
      "contains the payload title escaped and correctly unescapes emojis"
    );
  });
});
