import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(`Post controls`, function () {
  test("accessibility of the likes list below the post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_2 button.like-count")
      .hasAria("pressed", "false", "show likes button isn't pressed");

    await click("#post_2 button.like-count");
    assert
      .dom("#post_2 button.like-count")
      .hasAria("pressed", "true", "show likes button is now pressed");

    assert
      .dom("#post_2 .small-user-list.who-liked .small-user-list-content")
      .hasAttribute("role", "list", "likes container has list role");

    assert
      .dom("#post_2 .small-user-list.who-liked a.trigger-user-card")
      .exists("avatars are rendered");

    assert
      .dom("#post_2 .small-user-list.who-liked a.trigger-user-card")
      .hasAria("hidden", "false", "avatars are not aria-hidden");
    assert
      .dom("#post_2 .small-user-list.who-liked a.trigger-user-card")
      .hasAttribute("role", "listitem", "avatars have listitem role");
  });

  test("accessibility of the embedded replies below the post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 button.show-replies")
      .hasAria("pressed", "false", "show replies button isn't pressed");
    assert
      .dom("#post_1 button.show-replies")
      .hasAria(
        "label",
        i18n("post.sr_expand_replies", { count: 1 }),
        "show replies button has aria-label"
      );

    await click("#post_1 button.show-replies");
    assert
      .dom("#post_1 button.show-replies")
      .hasAria("pressed", "true", "show replies button is now pressed");

    // const replies = Array.from(queryAll("#post_1 .embedded-posts .reply"));
    assert
      .dom("#post_1 .embedded-posts .reply")
      .exists({ count: 1 }, "replies are rendered");

    assert
      .dom("#post_1 .embedded-posts .reply")
      .hasAttribute("role", "region", "replies have region role");
    assert.dom("#post_1 .embedded-posts .reply").hasAria(
      "label",
      i18n("post.sr_embedded_reply_description", {
        post_number: 1,
        username: "somebody",
      }),
      "replies have aria-label"
    );
    assert
      .dom("#post_1 .embedded-posts .btn.collapse-up")
      .hasAria(
        "label",
        i18n("post.sr_collapse_replies"),
        "collapse button has aria-label"
      );
  });
});
