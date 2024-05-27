import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

acceptance("Table Builder", function (needs) {
  needs.user();

  test("Can see table builder button when creating a topic", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await click(".d-editor-button-bar .options");
    await selectKit(".toolbar-popup-menu-options").expand();

    assert
      .dom(`.select-kit-row[data-name='${I18n.t("composer.insert_table")}']`)
      .exists("it shows the builder button");
  });

  test("Can see table builder button when editing post", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#post_1 .show-more-actions");
    await click("#post_1 .edit");
    assert.ok(exists("#reply-control"));
    await click(".d-editor-button-bar .options");
    await selectKit(".toolbar-popup-menu-options").expand();

    assert
      .dom(`.select-kit-row[data-name='${I18n.t("composer.insert_table")}']`)
      .exists("it shows the builder button");
  });
});
