import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Shared Drafts", function () {
  test("Viewing and publishing", async function (assert) {
    await visit("/t/some-topic/9");
    assert.dom(".shared-draft-controls").exists();
    let categoryChooser = selectKit(".shared-draft-controls .category-chooser");
    assert.strictEqual(categoryChooser.header().value(), "3");

    await click(".publish-shared-draft");
    await click(".dialog-footer .btn-primary");

    assert.dom(".shared-draft-controls").doesNotExist();
  });

  test("Updating category", async function (assert) {
    await visit("/t/some-topic/9");
    assert.dom(".shared-draft-controls").exists();

    await click(".edit-topic");

    let categoryChooser = selectKit(".edit-topic-title .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(7);

    await click(".edit-controls .btn-primary");

    categoryChooser = selectKit(".shared-draft-controls .category-chooser");
    assert.strictEqual(categoryChooser.header().value(), "7");
  });
});
