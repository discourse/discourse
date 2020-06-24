import I18n from "I18n";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Personal Message", {
  loggedIn: true
});

QUnit.test("footer edit button", async assert => {
  await visit("/t/pm-for-testing/12");

  assert.ok(
    !exists(".edit-message"),
    "does not show edit first post button on footer by default"
  );
});

QUnit.test("suggested messages", async assert => {
  await visit("/t/pm-for-testing/12");

  assert.equal(
    find("#suggested-topics .suggested-topics-title")
      .text()
      .trim(),
    I18n.t("suggested_topics.pm_title")
  );
});
