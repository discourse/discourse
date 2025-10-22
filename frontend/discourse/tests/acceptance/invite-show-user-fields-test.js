import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Accept Invite - User Fields", function (needs) {
  needs.site({
    user_fields: [
      {
        id: 34,
        name: "I've read the terms of service",
        field_type: "confirm",
        required: true,
        show_on_signup: true,
      },
      {
        id: 35,
        name: "What is your pet's name?",
        field_type: "text",
        required: true,
        show_on_signup: true,
      },
      {
        id: 36,
        name: "What's your dad like?",
        field_type: "text",
        required: false,
        show_on_signup: true,
      },
    ],
  });

  test("accept invite with user fields", async function (assert) {
    PreloadStore.store("invite_info", {
      invited_by: {
        id: 123,
        username: "neil",
        avatar_template: "/user_avatar/localhost/neil/{size}/25_1.png",
        name: "Neil Lalonde",
        title: "team",
      },
      email: "invited@asdf.com",
      username: "invited",
      is_invite_link: false,
    });

    await visit("/invites/myvalidinvitetoken");
    assert.dom(".invites-show").exists("shows the accept invite page");
    assert.dom(".user-field").exists("has at least one user field");
    assert.dom(".invites-show .btn-primary").isDisabled("submit is disabled");

    await fillIn("#new-account-name", "John Doe");
    await fillIn("#new-account-username", "validname");
    await fillIn("#new-account-password", "secur3ty4Y0uAndMe");

    assert.dom(".username-input .good").exists("username is valid");
    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("submit is still disabled due to lack of user fields");

    await fillIn(".user-field input[type=text]:nth-of-type(1)", "Barky");

    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("submit is disabled because field is not checked");

    await click(".user-field input[type=checkbox]");
    assert
      .dom(".invites-show .btn-primary")
      .isEnabled("submit is enabled because field is checked");

    await click(".user-field input[type=checkbox]");
    assert
      .dom(".invites-show .btn-primary")
      .isDisabled("toggling the checkbox disables the submit");
  });
});
