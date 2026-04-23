import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Reply target picker", function (needs) {
  needs.user({ id: 5, username: "kris" });

  test("the reply indicator in the edit title is a clickable button", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".topic-post[data-post-number='6'] button.edit");

    assert
      .dom("button.composer-edit-reply-to")
      .exists("renders the reply target as a button inside the action title");
  });

  test("the toolbar options menu exposes a 'Reply to another post' entry", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".topic-post[data-post-number='6'] button.edit");
    await click(".d-editor-button-bar .fk-d-menu__trigger");

    assert
      .dom("[data-name='change-reply-to']")
      .exists("the menu item is available for editors");
  });
});
