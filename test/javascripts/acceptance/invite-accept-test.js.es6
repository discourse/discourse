import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from "preload-store";

acceptance("Invite Accept", {
  settings: {
    full_name_required: true
  }
});

QUnit.test("Invite Acceptance Page", assert => {
  PreloadStore.store("invite_info", {
    invited_by: {
      id: 123,
      username: "neil",
      avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
      name: "Neil Lalonde",
      title: "team"
    },
    email: "invited@asdf.com",
    username: "invited"
  });

  visit("/invites/myvalidinvitetoken");
  andThen(() => {
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
      "submit is disabled because name is not filled"
    );
  });

  fillIn("#new-account-name", "John Doe");
  andThen(() => {
    assert.not(
      exists(".invites-show .btn-primary:disabled"),
      "submit is enabled"
    );
  });

  fillIn("#new-account-username", "a");
  andThen(() => {
    assert.ok(exists(".username-input .bad"), "username is not valid");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled"
    );
  });

  fillIn("#new-account-password", "aaa");
  andThen(() => {
    assert.ok(exists(".password-input .bad"), "password is not valid");
    assert.ok(
      exists(".invites-show .btn-primary:disabled"),
      "submit is disabled"
    );
  });

  fillIn("#new-account-username", "validname");
  fillIn("#new-account-password", "secur3ty4Y0uAndMe");
  andThen(() => {
    assert.ok(exists(".username-input .good"), "username is valid");
    assert.ok(exists(".password-input .good"), "password is valid");
    assert.not(
      exists(".invites-show .btn-primary:disabled"),
      "submit is enabled"
    );
  });
});
