import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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

    assert
      .dom("div#draft-status span")
      .doesNotExist("the draft was saved, there's no warning");

    await fillIn(".d-editor-input", "This won't be saved because of error");
    assert
      .dom("div#draft-status span")
      .hasText(
        i18n("composer.drafts_offline"),
        "the draft wasn't saved, a warning is rendered"
      );
    assert
      .dom("div#draft-status svg.d-icon-triangle-exclamation")
      .exists("an exclamation icon is rendered");

    await fillIn(".d-editor-input", draftThatWillBeSaved);
    assert
      .dom("div#draft-status span")
      .doesNotExist("the draft was saved again, the warning has disappeared");
  });
});
