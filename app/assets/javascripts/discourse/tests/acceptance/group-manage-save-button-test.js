import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

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

    assert.ok(exists(".alert-private-group-name"), "alert is shown");

    await visibilitySelector.expand();
    await visibilitySelector.selectRowByValue("0");

    assert.notOk(exists(".alert-private-group-name"), "alert is hidden");
  });
});
