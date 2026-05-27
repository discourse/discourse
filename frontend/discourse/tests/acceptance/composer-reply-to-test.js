import { click, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Reply target picker", function (needs) {
  needs.user({ id: 5, username: "kris" });

  // The topic fixture caches post 6 without `raw`, so the edit flow's
  // `store.find("post", ...)` has to fetch it fresh — mock that response
  // with a reply target set.
  needs.pretender((server, helper) => {
    server.get("/posts/3654", () =>
      helper.response({
        id: 3654,
        post_number: 6,
        topic_id: 280,
        raw: "Yes, I really like the concept of fuzzy matching for localization.",
        reply_to_post_number: 5,
        reply_to_user: {
          username: "pekka",
          name: "Pekka",
          avatar_template: "/images/avatar.png",
        },
        can_edit: true,
        version: 1,
        locale: null,
      })
    );
  });

  async function openEditForReplyPost() {
    await visit("/t/internationalization-localization/280");
    // Post 6 isn't the current user's, so the edit button is collapsed into
    // the "show more" overflow by default — expand it first.
    await click("article#post_6 button.show-more-actions");
    await click("article#post_6 button.edit");
    await waitFor(".d-editor-input");
  }

  test("the reply indicator in the edit title is a clickable button", async function (assert) {
    await openEditForReplyPost();

    assert
      .dom("button.composer-edit-reply-to")
      .exists("renders the reply target as a button inside the action title");
  });

  test("the toolbar options menu exposes a 'Reply to another post' entry", async function (assert) {
    await openEditForReplyPost();
    await click(".toolbar-menu__options-trigger");

    assert
      .dom("[data-name='change-reply-to']")
      .exists("the menu item is available for editors");
  });
});
