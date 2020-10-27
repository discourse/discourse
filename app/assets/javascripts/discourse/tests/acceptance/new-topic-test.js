import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("New Topic - Anonymous", function () {
  test("accessing new-topic route when logged out", async (assert) => {
    await visit("/new-topic?title=topic%20title&body=topic%20body");

    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});

acceptance("New Topic - Authenticated", function (needs) {
  needs.user();
  test("accessing new-topic route when logged in", async (assert) => {
    await visit(
      "/new-topic?title=topic%20title&body=topic%20body&category=bug"
    );

    assert.ok(exists(".composer-fields"), "it opens composer");
    assert.equal(
      find("#reply-title").val().trim(),
      "topic title",
      "it pre-fills topic title"
    );
    assert.equal(
      find(".d-editor-input").val().trim(),
      "topic body",
      "it pre-fills topic body"
    );
    assert.equal(
      selectKit(".category-chooser").header().value(),
      1,
      "it selects desired category"
    );
  });
});
