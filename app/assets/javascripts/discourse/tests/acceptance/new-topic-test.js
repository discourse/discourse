import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("New Topic - Anonymous", function () {
  test("accessing new-topic route when logged out", async function (assert) {
    await visit("/new-topic?title=topic%20title&body=topic%20body");

    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});

acceptance("New Topic - Authenticated", function (needs) {
  needs.user();
  test("accessing new-topic route when logged in", async function (assert) {
    await visit(
      "/new-topic?title=topic%20title&body=topic%20body&category=bug"
    );

    assert.ok(exists(".composer-fields"), "it opens composer");
    assert.strictEqual(
      query("#reply-title").value.trim(),
      "topic title",
      "it pre-fills topic title"
    );
    assert.strictEqual(
      query(".d-editor-input").value.trim(),
      "topic body",
      "it pre-fills topic body"
    );
    assert.strictEqual(
      selectKit(".category-chooser").header().value(),
      "1",
      "it selects desired category"
    );
  });
});
