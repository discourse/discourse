import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Edit - Moderation", function (needs) {
  needs.user();

  test("moderation tab appears in nav", async function (assert) {
    await visit("/c/bug/edit/moderation");

    assert.dom(".edit-category-moderation").exists("moderation tab is in nav");
    assert
      .dom(".edit-category-moderation a")
      .hasText("Moderation", "tab has correct label");
  });

  test("moderation tab renders slow mode and auto-close fields", async function (assert) {
    await visit("/c/bug/edit/moderation");

    assert.dom("input#category-default-slow-mode").exists();
    assert.dom("input#topic-auto-close").exists();
    assert.dom("input#category-number-daily-bump").exists();
    assert.dom("input#category-auto-bump-cooldown-days").exists();
  });

  test("moderation tab renders topic and reply approval controls", async function (assert) {
    await visit("/c/bug/edit/moderation");

    assert.dom(".topic-approval-type select").exists();
    assert.dom(".reply-approval-type select").exists();
  });
});

acceptance("Category Edit - Moderation - group moderation", function (needs) {
  needs.user();
  needs.settings({ enable_category_group_moderation: true });

  test("reviewer groups field is shown when group moderation enabled", async function (assert) {
    await visit("/c/bug/edit/moderation");

    assert.dom(".reviewable-by-group").exists();
  });
});
