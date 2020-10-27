import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit, click, fillIn } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import PreloadStore from "discourse/lib/preload-store";

acceptance("Account Created", function () {
  test("account created - message", async (assert) => {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
    });
    await visit("/u/account-created");

    assert.ok(exists(".account-created"));
    assert.equal(
      find(".account-created .ac-message").text().trim(),
      "Hello World",
      "it displays the message"
    );
    assert.notOk(exists(".activation-controls"));
  });

  test("account created - resend email", async (assert) => {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    assert.ok(exists(".account-created"));
    assert.equal(
      find(".account-created .ac-message").text().trim(),
      "Hello World",
      "it displays the message"
    );

    await click(".activation-controls .resend");

    assert.equal(currentPath(), "account-created.resent");
    const email = find(".account-created .ac-message b").text();
    assert.equal(email, "eviltrout@example.com");
  });

  test("account created - update email - cancel", async (assert) => {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    await click(".activation-controls .edit-email");

    assert.equal(currentPath(), "account-created.edit-email");
    assert.ok(find(".activation-controls .btn-primary:disabled").length);

    await click(".activation-controls .edit-cancel");

    assert.equal(currentPath(), "account-created.index");
  });

  test("account created - update email - submit", async (assert) => {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    await click(".activation-controls .edit-email");

    assert.ok(find(".activation-controls .btn-primary:disabled").length);

    await fillIn(".activate-new-email", "newemail@example.com");

    assert.notOk(find(".activation-controls .btn-primary:disabled").length);

    await click(".activation-controls .btn-primary");

    assert.equal(currentPath(), "account-created.resent");
    const email = find(".account-created .ac-message b").text();
    assert.equal(email, "newemail@example.com");
  });
});
