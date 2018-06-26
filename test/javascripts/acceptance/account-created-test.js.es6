import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from "preload-store";

acceptance("Account Created");

QUnit.test("account created - message", assert => {
  PreloadStore.store("accountCreated", {
    message: "Hello World"
  });
  visit("/u/account-created");

  andThen(() => {
    assert.ok(exists(".account-created"));
    assert.equal(
      find(".account-created .ac-message")
        .text()
        .trim(),
      "Hello World",
      "it displays the message"
    );
    assert.notOk(exists(".activation-controls"));
  });
});

QUnit.test("account created - resend email", assert => {
  PreloadStore.store("accountCreated", {
    message: "Hello World",
    username: "eviltrout",
    email: "eviltrout@example.com",
    show_controls: true
  });
  visit("/u/account-created");

  andThen(() => {
    assert.ok(exists(".account-created"));
    assert.equal(
      find(".account-created .ac-message")
        .text()
        .trim(),
      "Hello World",
      "it displays the message"
    );
  });

  click(".activation-controls .resend");
  andThen(() => {
    assert.equal(currentPath(), "account-created.resent");
    const email = find(".account-created .ac-message b").text();
    assert.equal(email, "eviltrout@example.com");
  });
});

QUnit.test("account created - update email - cancel", assert => {
  PreloadStore.store("accountCreated", {
    message: "Hello World",
    username: "eviltrout",
    email: "eviltrout@example.com",
    show_controls: true
  });
  visit("/u/account-created");

  click(".activation-controls .edit-email");
  andThen(() => {
    assert.equal(currentPath(), "account-created.edit-email");
    assert.ok(find(".activation-controls .btn-primary:disabled").length);
  });

  click(".activation-controls .edit-cancel");
  andThen(() => {
    assert.equal(currentPath(), "account-created.index");
  });
});

QUnit.test("account created - update email - submit", assert => {
  PreloadStore.store("accountCreated", {
    message: "Hello World",
    username: "eviltrout",
    email: "eviltrout@example.com",
    show_controls: true
  });
  visit("/u/account-created");

  click(".activation-controls .edit-email");
  andThen(() => {
    assert.ok(find(".activation-controls .btn-primary:disabled").length);
  });

  fillIn(".activate-new-email", "newemail@example.com");
  andThen(() => {
    assert.notOk(find(".activation-controls .btn-primary:disabled").length);
  });

  click(".activation-controls .btn-primary");
  andThen(() => {
    assert.equal(currentPath(), "account-created.resent");
    const email = find(".account-created .ac-message b").text();
    assert.equal(email, "newemail@example.com");
  });
});
