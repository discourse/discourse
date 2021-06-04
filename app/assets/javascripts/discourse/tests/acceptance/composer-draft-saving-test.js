import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Composer - Draft saving", function (needs) {
  needs.user();

  let callNumber = 0;
  needs.pretender((server, helper) => {
    server.post("/draft.json", () => {
      // every even call is successful
      callNumber++;
      const success = callNumber % 2 !== 0;
      return success
        ? helper.response({ success: true })
        : helper.response(500, {});
    });
  });

  test("Shows a warning if a draft wasn't saved", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    await fillIn(".d-editor-input", "This will be saved successfully");
    assert.notOk(
      exists("div#draft-status span"),
      "the draft was saved, there's no a warning"
    );

    await fillIn(".d-editor-input", "This won't be saved because of error");
    assert.equal(
      query("div#draft-status span").innerText.trim(),
      I18n.t("composer.drafts_offline"),
      "the draft wasn't saved, a warning is rendered"
    );
    assert.ok(
      exists("div#draft-status svg.d-icon-exclamation-triangle"),
      "an exclamation icon is rendered"
    );

    await fillIn(".d-editor-input", "This will be saved successfully");
    assert.notOk(
      exists("div#draft-status span"),
      "the draft was saved again, the warning has disappeared"
    );
  });
});
