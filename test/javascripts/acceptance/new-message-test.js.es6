import { acceptance } from "helpers/qunit-helpers";

acceptance("New Message");

QUnit.test("accessing new-message route when logged out", async assert => {
  await visit(
    "/new-message?username=charlie&title=message%20title&body=message%20body"
  );

  assert.ok(exists(".modal.login-modal"), "it shows the login modal");
});

acceptance("New Message", { loggedIn: true });
QUnit.test("accessing new-message route when logged in", async assert => {
  await visit(
    "/new-message?username=charlie&title=message%20title&body=message%20body"
  );

  assert.ok(exists(".composer-fields"), "it opens composer");
  assert.equal(
    find("#reply-title")
      .val()
      .trim(),
    "message title",
    "it pre-fills message title"
  );
  assert.equal(
    find(".d-editor-input")
      .val()
      .trim(),
    "message body",
    "it pre-fills message body"
  );
  assert.equal(
    find(".users-input .item:eq(0)")
      .text()
      .trim(),
    "charlie",
    "it selects correct username"
  );
});
