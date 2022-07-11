import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Personal Message", function (needs) {
  needs.user();

  test("footer edit button", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert.ok(
      !exists(".edit-message"),
      "does not show edit first post button on footer by default"
    );
  });

  test("suggested messages", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert.strictEqual(
      query("#suggested-topics .suggested-topics-title").innerText.trim(),
      I18n.t("suggested_topics.pm_title")
    );
  });
});
