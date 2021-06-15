import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Composer - Edit conflict", function (needs) {
  needs.user();

  let lastBody;
  needs.pretender((server, helper) => {
    server.post("/draft.json", (request) => {
      lastBody = request.requestBody;
      return helper.response({ success: true });
    });
  });

  QUnit.skip(
    "Edit a post that causes an edit conflict",
    async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click(".topic-post:nth-of-type(1) button.show-more-actions");
      await click(".topic-post:nth-of-type(1) button.edit");
      await fillIn(".d-editor-input", "this will 409");
      await click("#reply-control button.create");
      assert.equal(
        queryAll("#reply-control button.create").text().trim(),
        I18n.t("composer.overwrite_edit"),
        "it shows the overwrite button"
      );
      assert.ok(
        queryAll("#draft-status .d-icon-user-edit"),
        "error icon should be there"
      );
      await click(".modal .btn-primary");
    }
  );

  test("Should not send originalText when posting a new reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
    assert.ok(lastBody.indexOf("originalText") === -1);
  });

  test("Should send originalText when editing a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
    assert.ok(lastBody.indexOf("originalText") > -1);
  });
});
