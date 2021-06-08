import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentRouteName, fillIn, visit } from "@ember/test-helpers";
import PreloadStore from "discourse/lib/preload-store";
import { test } from "qunit";

acceptance("Account Created", function () {
  test("account created - message", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
    });
    await visit("/u/account-created");

    assert.ok(exists(".account-created"));
    assert.equal(
      queryAll(".account-created .ac-message").text().trim(),
      "Hello World",
      "it displays the message"
    );
    assert.notOk(exists(".activation-controls"));
  });

  test("account created - resend email", async function (assert) {
    PreloadStore.store("accountCreated", {
      message: "Hello World",
      username: "eviltrout",
      email: "eviltrout@example.com",
      show_controls: true,
    });

    await visit("/u/account-created");

    assert.ok(exists(".account-created"));
    assert.equal(
      queryAll(".account-created .ac-message").text().trim(),
      "Hello World",
      "it displays the message"
    );

    await click(".activation-controls .resend");

    assert.equal(currentRouteName(), "account-created.resent");
    const email = queryAll(".account-created .ac-message b").text();
    assert.equal(email, "eviltrout@example.com");
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

    assert.equal(currentRouteName(), "account-created.edit-email");
    assert.ok(exists(".activation-controls .btn-primary:disabled"));

    await click(".activation-controls .edit-cancel");

    assert.equal(currentRouteName(), "account-created.index");
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

    assert.ok(exists(".activation-controls .btn-primary:disabled"));

    await fillIn(".activate-new-email", "newemail@example.com");

    assert.notOk(exists(".activation-controls .btn-primary:disabled"));

    await click(".activation-controls .btn-primary");

    assert.equal(currentRouteName(), "account-created.resent");
    const email = queryAll(".account-created .ac-message b").text();
    assert.equal(email, "newemail@example.com");
  });
});
