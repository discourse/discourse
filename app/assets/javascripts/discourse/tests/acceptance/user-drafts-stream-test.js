import {
  acceptance,
  count,
  exists,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("User Drafts", function (needs) {
  needs.user();

  test("Stream", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.equal(count(".user-stream-item"), 3, "has drafts");

    await click(".user-stream-item:last-child .remove-draft");
    assert.ok(visible(".bootbox"));

    await click(".bootbox .btn-primary");
    assert.equal(
      count(".user-stream-item"),
      2,
      "draft removed, list length diminished by one"
    );
  });

  test("Stream - resume draft", async function (assert) {
    await visit("/u/eviltrout/activity/drafts");
    assert.ok(exists(".user-stream-item"), "has drafts");

    await click(".user-stream-item .resume-draft");
    assert.equal(
      queryAll(".d-editor-input").val().trim(),
      "A fun new topic for testing drafts."
    );
  });
});
