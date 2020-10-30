import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("New Message - Anonymous", function () {
  test("accessing new-message route when logged out", async (assert) => {
    await visit(
      "/new-message?username=charlie&title=message%20title&body=message%20body"
    );

    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});

acceptance("New Message - Authenticated", function (needs) {
  needs.user();

  test("accessing new-message route when logged in", async (assert) => {
    await visit(
      "/new-message?username=charlie&title=message%20title&body=message%20body"
    );

    assert.ok(exists(".composer-fields"), "it opens composer");
    assert.equal(
      queryAll("#reply-title").val().trim(),
      "message title",
      "it pre-fills message title"
    );
    assert.equal(
      queryAll(".d-editor-input").val().trim(),
      "message body",
      "it pre-fills message body"
    );
    assert.equal(
      queryAll(".users-input .item:eq(0)").text().trim(),
      "charlie",
      "it selects correct username"
    );
  });
});
