import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Edit conflict", function (needs) {
  needs.user();

  let lastBody;
  needs.pretender((server, helper) => {
    server.post("/drafts.json", (request) => {
      lastBody = request.requestBody;
      return helper.response({ success: true });
    });
  });

  test("Should not send originalText when posting a new reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
    assert.false(lastBody.includes("originalText"));
  });

  test("Should send originalText when editing a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
    assert.true(lastBody.includes("originalText"));
  });
});
