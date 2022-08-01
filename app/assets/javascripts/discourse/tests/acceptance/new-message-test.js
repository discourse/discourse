import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("New Message - Anonymous", function () {
  test("accessing new-message route when logged out", async function (assert) {
    await visit(
      "/new-message?username=charlie&title=message%20title&body=message%20body"
    );

    assert.ok(exists(".modal.login-modal"), "it shows the login modal");
  });
});

acceptance("New Message - Authenticated", function (needs) {
  needs.user();

  test("accessing new-message route when logged in", async function (assert) {
    await visit(
      "/new-message?username=charlie,john&title=message%20title&body=message%20body"
    );

    assert.ok(exists(".composer-fields"), "it opens composer");
    assert.strictEqual(
      query("#reply-title").value.trim(),
      "message title",
      "it pre-fills message title"
    );
    assert.strictEqual(
      query(".d-editor-input").value.trim(),
      "message body",
      "it pre-fills message body"
    );

    const privateMessageUsers = selectKit("#private-message-users");
    assert.strictEqual(
      privateMessageUsers.header().value(),
      "charlie,john",
      "it selects correct username"
    );
  });
});
