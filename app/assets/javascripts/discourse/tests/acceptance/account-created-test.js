import { click, currentRouteName, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Account Created", function () {
  test("account created - message", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
    });
    await visit("/u/account-created");

    assert.dom(".account-created").exists();
    assert
      .dom(".account-created .success-info")
      .hasText("Hello World", "it displays the message");
    assert.dom(".activation-controls").doesNotExist();
  });

  test("account created - resend email", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    assert.dom(".account-created").exists();
    assert
      .dom(".account-created .success-info")
      .hasText("Hello World", "it displays the message");

    await click(".activation-controls .resend");

    assert.strictEqual(currentRouteName(), "account-created.resent");
    assert.dom(".account-created b").hasText("eviltrout@example.com");
  });

  test("account created - update email - cancel", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    await click(".activation-controls .edit-email");

    assert.strictEqual(currentRouteName(), "account-created.edit-email");
    assert.dom(".activation-controls .btn-primary").isDisabled();

    await click(".activation-controls .edit-cancel");

    assert.strictEqual(currentRouteName(), "account-created.index");
  });

  test("account created - update email - submit", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");
    await click(".activation-controls .edit-email");
    assert.dom(".activation-controls .btn-primary").isDisabled();

    await fillIn(".activate-new-email", "newemail@example.com");
    assert.dom(".activation-controls .btn-primary").isNotDisabled();

    await click(".activation-controls .btn-primary");
    assert.strictEqual(currentRouteName(), "account-created.resent");
    assert.dom(".account-created b").hasText("newemail@example.com");
  });
});
