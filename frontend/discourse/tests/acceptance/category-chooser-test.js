import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("CategoryChooser", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: false,
  });

  test("does not display uncategorized if not allowed", async function (assert) {
    const categoryChooser = selectKit(".category-chooser");

    await visit("/");
    await click("#create-topic");
    await categoryChooser.expand();

    assert.notStrictEqual(
      categoryChooser.rowByIndex(0).name(),
      "uncategorized"
    );
  });

  test("prefill category when category_id is set", async function (assert) {
    await visit("/new-topic?category_id=1");

    assert.strictEqual(selectKit(".category-chooser").header().value(), "1");
  });
});

acceptance("CategoryChooser - new select controls", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: false,
    enable_new_select_controls: true,
  });

  test("a new topic from a category the user cannot post in offers it disabled", async function (assert) {
    await visit("/");
    Category.findById(1).permission = PermissionType.READONLY;
    await visit("/new-topic?category_id=1");
    await dSelect(".category-chooser").open();

    const option = ".d-select__option[data-value='1']";
    assert.dom(option).hasAttribute("aria-disabled", "true");
    assert
      .dom(`${option} .d-select__option-description`)
      .hasText(i18n("category_row.read_only_description"));
  });
});
