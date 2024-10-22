import { click, tab, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Select-kit - Composer - Accessibility", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });
  needs.settings({ allow_uncategorized_topics: true });

  test("tabbing works", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const tagChooser = selectKit(".mini-tag-chooser");
    await tagChooser.expand();

    assert
      .dom(".mini-tag-chooser .filter-input")
      .isFocused("it should focus the filter by default");

    await tab();

    assert
      .dom(".mini-tag-chooser .select-kit-row:first-child")
      .isFocused("it should focus the first row next");

    await tab({ backwards: true });

    assert
      .dom(".mini-tag-chooser .filter-input")
      .isFocused("it should focus the filter again when tabbing backwards");

    await tab({ backwards: true });

    assert
      .dom(".mini-tag-chooser .select-kit-header")
      .isFocused("it should focus the tag chooser header next");

    await tab({ backwards: true });

    assert
      .dom(".category-chooser .select-kit-header")
      .isFocused("it should focus the category chooser header next");

    await tab();

    assert
      .dom(".mini-tag-chooser .select-kit-header")
      .isFocused("it should focus the tag chooser again");

    await tagChooser.expand();

    await triggerKeyEvent(
      ".mini-tag-chooser .select-kit-row:first-child",
      "keydown",
      "Escape"
    );

    assert
      .dom(".mini-tag-chooser .select-kit-body .select-kit-row")
      .doesNotExist("Hitting Escape dismisses the tag chooser");

    assert.ok(exists(".composer-fields"), "Escape does not dismiss composer");
  });
});
