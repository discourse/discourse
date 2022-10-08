import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Welcome Topic Banner", function (needs) {
  needs.user();
  needs.site({ show_welcome_topic_banner: true });

  test("Navigation", async function (assert) {
    await visit("/");
    assert.ok(exists(".welcome-cta"), "has the welcome topic banner");
    assert.ok(
      exists("button.welcome-cta__button"),
      "has the welcome topic edit button"
    );
  });
});
