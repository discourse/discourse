import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Discourse Post Voting - notifications", function (needs) {
  needs.user();
  needs.settings({ post_voting_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/notifications", () => {
      return helper.response({
        notifications: [
          {
            id: 1,
            user_id: 26,
            notification_type: 35,
            post_number: 1,
            topic_id: 59,
            fancy_title: "some fancy title",
            slug: "some-slug",
            data: {
              display_username: "some_user",
              post_voting_comment_id: 123,
            },
          },
        ],
        total_rows_notifications: 1,
      });
    });
  });

  test("viewing comments notifications", async (assert) => {
    await visit("/u/eviltrout/notifications");

    assert
      .dom(".user-notifications-list .notification .item-label")
      .hasText("some_user", "Renders username");

    assert
      .dom(".user-notifications-list .notification .item-description")
      .hasText("some fancy title", "Renders description");

    assert
      .dom(".user-notifications-list .notification a")
      .hasAttribute(
        "href",
        /\/t\/some-slug\/59#post-voting-comment-123/,
        "displays a link with a hash fragment pointing to the comment id"
      );

    assert
      .dom(".user-notifications-list .notification a")
      .hasAttribute(
        "title",
        i18n("notifications.titles.question_answer_user_commented"),
        "displays the right title"
      );
  });
});
