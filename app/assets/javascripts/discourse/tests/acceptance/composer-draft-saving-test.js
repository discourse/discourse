import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Composer - Draft saving", function (needs) {
  needs.user();

  const draftThatWillBeSaved = "This_will_be_saved_successfully";

  needs.pretender((server, helper) => {
    server.post("/drafts.json", (request) => {
      const success = request.requestBody.includes(draftThatWillBeSaved);
      return success
        ? helper.response({ success: true })
        : helper.response(500, {});
    });
  });

  test("Shows a warning if a draft wasn't saved", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    await fillIn(".d-editor-input", draftThatWillBeSaved);

    assert.notOk(
      exists("div#draft-status span"),
      "the draft was saved, there's no warning"
    );

    await fillIn(".d-editor-input", "This won't be saved because of error");
    assert
      .dom("div#draft-status span")
      .hasText(
        I18n.t("composer.drafts_offline"),
        "the draft wasn't saved, a warning is rendered"
      );
    assert.ok(
      exists("div#draft-status svg.d-icon-triangle-exclamation"),
      "an exclamation icon is rendered"
    );

    await fillIn(".d-editor-input", draftThatWillBeSaved);
    assert.notOk(
      exists("div#draft-status span"),
      "the draft was saved again, the warning has disappeared"
    );
  });
});
