import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Personal Message", function (needs) {
  needs.user();

  test("footer edit button", async (assert) => {
    await visit("/t/pm-for-testing/12");

    assert.ok(
      !exists(".edit-message"),
      "does not show edit first post button on footer by default"
    );
  });

  test("suggested messages", async (assert) => {
    await visit("/t/pm-for-testing/12");

    assert.equal(
      find("#suggested-topics .suggested-topics-title").text().trim(),
      I18n.t("suggested_topics.pm_title")
    );
  });
});
