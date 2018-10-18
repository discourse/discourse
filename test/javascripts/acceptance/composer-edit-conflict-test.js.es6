import { acceptance } from "helpers/qunit-helpers";

acceptance("Composer - Edit conflict", {
  loggedIn: true,

  pretend(server, helper) {
    server.put("/posts/18", () => {
      return helper.response(409, { errors: ["edit conflict"] });
    });
  }
});

QUnit.skip("Edit a post that causes an edit conflict", async assert => {
  await visit("/t/this-is-a-test-topic/9");
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
});
