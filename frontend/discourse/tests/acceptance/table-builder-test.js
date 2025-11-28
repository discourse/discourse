import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(`Table Builder`, function (needs) {
  needs.user();

  test("Can see table builder button when creating a topic", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await click(".toolbar-menu__options-trigger");

    assert
      .dom("button[data-name='toggle-spreadsheet']")
      .exists("it shows the builder button");
  });

  test("Can see table builder button when editing post", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#post_1 .show-more-actions");
    await click("#post_1 .edit");
    assert.dom("#reply-control").exists();
    await click(".toolbar-menu__options-trigger");

    assert
      .dom("button[data-name='toggle-spreadsheet']")
      .exists("it shows the builder button");
  });
});
