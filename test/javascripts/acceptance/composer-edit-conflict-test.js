import I18n from "I18n";
import { acceptance } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";

acceptance("Composer - Edit conflict", {
  loggedIn: true
});

QUnit.test("Edit a post that causes an edit conflict", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.edit");
  await fillIn(".d-editor-input", "this will 409");
  await click("#reply-control button.create");
  assert.equal(
    find("#reply-control button.create")
      .text()
      .trim(),
    I18n.t("composer.overwrite_edit"),
    "it shows the overwrite button"
  );
  assert.ok(
    find("#draft-status .d-icon-user-edit"),
    "error icon should be there"
  );
  await click(".modal .btn-primary");
});

function handleDraftPretender(assert) {
  pretender.post("/draft.json", request => {
    if (
      request.requestBody.indexOf("%22reply%22%3A%22%22") === -1 &&
      request.requestBody.indexOf("Any+plans+to+support+localization") !== -1
    ) {
      assert.notEqual(request.requestBody.indexOf("originalText"), -1);
    }
    if (
      request.requestBody.indexOf(
        "draft_key=topic_280&sequence=4&data=%7B%22reply%22%3A%22hello+world+hello+world+hello+world+hello+world+hello+world%22%2C%22action%22%3A%22reply%22%2C%22categoryId%22%3A2%2C%22archetypeId%22%3A%22regular%22%2C%22metaData"
      ) !== -1
    ) {
      assert.equal(
        request.requestBody.indexOf("originalText"),
        -1,
        request.requestBody
      );
    }
    return [200, { "Content-Type": "application/json" }, { success: true }];
  });
}

QUnit.test(
  "Should not send originalText when posting a new reply",
  async assert => {
    handleDraftPretender(assert);

    await visit("/t/internationalization-localization/280");
    await click(".topic-post:eq(0) button.reply");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
  }
);

QUnit.test("Should send originalText when editing a reply", async assert => {
  handleDraftPretender(assert);

  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.edit");
  await fillIn(
    ".d-editor-input",
    "hello world hello world hello world hello world hello world"
  );
});
