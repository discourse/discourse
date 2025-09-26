import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance(`Post controls`, function () {
  test("menu of like count is shown when clicking on like count", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom("#post_2 .button-count").exists("like count button exists");

    await click("#post_2 .button-count");

    // Assert that the liked users list container appears
    assert
      .dom(".liked-users-list__container")
      .exists("liked users list container appears");
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
