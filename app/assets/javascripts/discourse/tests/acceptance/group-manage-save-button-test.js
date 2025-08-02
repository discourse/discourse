import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Managing Group - Save Button", function (needs) {
  needs.user();

  test("restricting visibility and selecting primary group checkbox", async function (assert) {
    await visit("/g/alternative-group/manage/membership");

    await click(".groups-form-primary-group");

    await click('a[href="/g/alternative-group/manage/interaction"]');

    const visibilitySelector = selectKit(
      ".select-kit.groups-form-visibility-level"
    );
    await visibilitySelector.expand();
    await visibilitySelector.selectRowByValue("1");

    assert.dom(".alert-private-group-name").exists("alert is shown");

    await visibilitySelector.expand();
    await visibilitySelector.selectRowByValue("0");

    assert.dom(".alert-private-group-name").doesNotExist("alert is hidden");
  });
});
