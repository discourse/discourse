import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, tab, triggerKeyEvent, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Select-kit - Composer - Accessibility", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });
  needs.settings({ allow_uncategorized_topics: true });

  test("tabbing works", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const tagChooser = selectKit(".mini-tag-chooser");
    await tagChooser.expand();

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".mini-tag-chooser .filter-input"),
      "it should focus the filter by default"
    );

    await tab();

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".mini-tag-chooser .select-kit-row:first-child"),
      "it should focus the first row next"
    );

    await tab({ backwards: true });

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".mini-tag-chooser .filter-input"),
      "it should focus the filter again when tabbing backwards"
    );

    await tab({ backwards: true });

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".mini-tag-chooser .select-kit-header"),
      "it should focus the tag chooser header next"
    );

    await tab({ backwards: true });

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".category-chooser .select-kit-header"),
      "it should focus the category chooser header next"
    );

    await tab();

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".mini-tag-chooser .select-kit-header"),
      "it should focus the tag chooser again"
    );

    await tagChooser.expand();

    await triggerKeyEvent(
      ".mini-tag-chooser .select-kit-row:first-child",
      "keydown",
      "Escape"
    );

    assert.notOk(
      exists(".mini-tag-chooser .select-kit-body .select-kit-row"),
      "Hitting Escape dismisses the tag chooser"
    );

    assert.ok(exists(".composer-fields"), "Escape does not dismiss composer");
  });
});
