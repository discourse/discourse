import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Shared Drafts", function () {
  test("Viewing and publishing", async function (assert) {
    await visit("/t/some-topic/9");
    assert.equal(count(".shared-draft-controls"), 1);
    let categoryChooser = selectKit(".shared-draft-controls .category-chooser");
    assert.equal(categoryChooser.header().value(), "3");

    await click(".publish-shared-draft");
    await click(".bootbox .btn-primary");

    assert.ok(!exists(".shared-draft-controls"));
  });

  test("Updating category", async function (assert) {
    await visit("/t/some-topic/9");
    assert.equal(count(".shared-draft-controls"), 1);

    await click(".edit-topic");

    let categoryChooser = selectKit(".edit-topic-title .category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(7);

    await click(".edit-controls .btn-primary");

    categoryChooser = selectKit(".shared-draft-controls .category-chooser");
    assert.equal(categoryChooser.header().value(), "7");
  });
});
