import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("New Message - Anonymous", function () {
  test("accessing new-message route when logged out", async function (assert) {
    await visit(
      "/new-message?username=charlie&title=message%20title&body=message%20body"
    );

    assert.dom(".login-fullpage").exists("shows the login page");
  });
});

acceptance("New Message - Authenticated", function (needs) {
  needs.user();

  test("accessing new-message route when logged in", async function (assert) {
    await visit(
      "/new-message?username=charlie,john&title=message%20title&body=message%20body"
    );

    assert.dom(".composer-fields").exists("opens the composer");
    assert
      .dom("#reply-title")
      .hasValue("message title", "pre-fills message title");
    assert
      .dom(".d-editor-input")
      .hasValue("message body", "pre-fills message body");

    const privateMessageUsers = selectKit("#private-message-users");
    assert.strictEqual(
      privateMessageUsers.header().value(),
      "charlie,john",
      "it selects correct username"
    );
  });
});
