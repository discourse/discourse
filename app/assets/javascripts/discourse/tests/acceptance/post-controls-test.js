import {
  acceptance,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Post controls", function () {
  test("accessibility of the likes list below the post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const showLikesButton = query("#post_2 button.like-count");
    assert.equal(
      showLikesButton.getAttribute("aria-pressed"),
      "false",
      "show likes button isn't pressed"
    );
    assert.equal(
      showLikesButton.getAttribute("aria-label"),
      I18n.t("post.sr_post_like_count_button", { count: 4 }),
      "show likes button has aria-label"
    );

    await click(showLikesButton);
    assert.equal(
      showLikesButton.getAttribute("aria-pressed"),
      "true",
      "show likes button is now pressed"
    );

    const likesContainer = query("#post_2 .small-user-list.who-liked");
    assert.equal(
      likesContainer.getAttribute("role"),
      "list",
      "likes container has list role"
    );
    assert.equal(
      likesContainer.getAttribute("aria-label"),
      I18n.t("post.actions.people.sr_post_likers_list_description"),
      "likes container has aria-label"
    );
    assert.equal(
      likesContainer
        .querySelector(".list-description")
        .getAttribute("aria-hidden"),
      "true",
      "list description is aria-hidden"
    );

    const likesAvatars = likesContainer.querySelectorAll("a.trigger-user-card");
    assert.ok(likesAvatars.length > 0, "avatars are rendered");
    likesAvatars.forEach((avatar) => {
      assert.equal(
        avatar.getAttribute("aria-hidden"),
        "false",
        "avatars are not aria-hidden"
      );
      assert.equal(
        avatar.getAttribute("role"),
        "listitem",
        "avatars have listitem role"
      );
    });
  });

  test("accessibility of the embedded replies below the post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const showRepliesButton = query("#post_1 button.show-replies");
    assert.equal(
      showRepliesButton.getAttribute("aria-pressed"),
      "false",
      "show replies button isn't pressed"
    );
    assert.equal(
      showRepliesButton.getAttribute("aria-label"),
      I18n.t("post.sr_expand_replies", { count: 1 }),
      "show replies button has aria-label"
    );

    await click(showRepliesButton);
    assert.equal(
      showRepliesButton.getAttribute("aria-pressed"),
      "true",
      "show replies button is now pressed"
    );

    const replies = Array.from(queryAll("#post_1 .embedded-posts .reply"));
    assert.equal(replies.length, 1, "replies are rendered");
    replies.forEach((reply) => {
      assert.equal(
        reply.getAttribute("role"),
        "region",
        "replies have region role"
      );
      assert.equal(
        reply.getAttribute("aria-label"),
        I18n.t("post.sr_embedded_reply_description", {
          post_number: 1,
          username: "somebody",
        }),
        "replies have aria-label"
      );
    });
    assert.equal(
      query("#post_1 .embedded-posts .btn.collapse-up").getAttribute(
        "aria-label"
      ),
      I18n.t("post.sr_collapse_replies"),
      "collapse button has aria-label"
    );
  });
});
