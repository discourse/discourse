import { acceptance } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";

acceptance("Composer - Edit conflict", {
  loggedIn: true
});

QUnit.test("Edit a post that causes an edit conflict", async assert => {
  pretender().put("/posts/398", () => [
    409,
    { "Content-Type": "application/json" },
    { errors: ["edit conflict"] }
  ]);

  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.edit");
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

QUnit.test(
  "Should not send originalText when posting a new reply",
  async assert => {
    pretender().post("/draft.json", request => {
      assert.equal(
        request.requestBody.indexOf("originalText"),
        -1,
        request.requestBody
      );
      return [200, { "Content-Type": "application/json" }, { success: true }];
    });

    await visit("/t/internationalization-localization/280");
    await click(".topic-post:eq(0) button.reply");
    await fillIn(
      ".d-editor-input",
      "hello world hello world hello world hello world hello world"
    );
  }
);

QUnit.test("Should send originalText when editing a reply", async assert => {
  pretender().post("/draft.json", request => {
    if (request.requestBody.indexOf("%22reply%22%3A%22%22") === -1) {
      assert.notEqual(request.requestBody.indexOf("originalText"), -1);
    }
    return [200, { "Content-Type": "application/json" }, { success: true }];
  });

  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.edit");
  await fillIn(
    ".d-editor-input",
    "hello world hello world hello world hello world hello world"
  );
});
