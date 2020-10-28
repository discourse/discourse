import { exists } from "discourse/tests/helpers/qunit-helpers";
import { fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import PreloadStore from "discourse/lib/preload-store";

acceptance("Invite Accept", function (needs) {
  needs.settings({ full_name_required: true });

  test("Invite Acceptance Page", async (assert) => {
    PreloadStore.store("invite_info", {
      invited_by: {
        id: 123,
        username: "neil",
        avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
        name: "Neil Lalonde",
        title: "team",
      },
      email: null,
      username: "invited",
      is_invite_link: true,
    });

    await visit("/invites/myvalidinvitetoken");
    assert.ok(exists("#new-account-email"), "shows the email input");
    assert.ok(exists("#new-account-username"), "shows the username input");
    assert.equal(
      find("#new-account-username").val(),
      "invited",
      "username is prefilled"
    );
    assert.ok(exists("#new-account-name"), "shows the name input");
    assert.ok(exists("#new-account-password"), "shows the password input");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled because name and email is not filled"
    );

    await fillIn("#new-account-name", "John Doe");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled because email is not filled"
    );

    await fillIn("#new-account-email", "john.doe@example.com");
    assert.not(
      exists(".invites-show .btn-primary:disabled"),
      "submit is enabled"
    );

    await fillIn("#new-account-username", "a");
    assert.ok(exists(".username-input .bad"), "username is not valid");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled"
    );

    await fillIn("#new-account-password", "aaa");
    assert.ok(exists(".password-input .bad"), "password is not valid");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled"
    );

    await fillIn("#new-account-email", "john.doe@example");
    assert.ok(exists(".email-input .bad"), "email is not valid");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled"
    );

    await fillIn("#new-account-username", "validname");
    await fillIn("#new-account-password", "secur3ty4Y0uAndMe");
    await fillIn("#new-account-email", "john.doe@example.com");
    assert.ok(exists(".username-input .good"), "username is valid");
    assert.ok(exists(".password-input .good"), "password is valid");
    assert.ok(exists(".email-input .good"), "email is valid");
    assert.not(
      exists(".invites-show .btn-primary:disabled"),
      "submit is enabled"
    );
  });
});
