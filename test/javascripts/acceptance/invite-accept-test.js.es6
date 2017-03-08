import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from 'preload-store';

acceptance("Invite Accept");

test("Invite Acceptance Page", () => {
  PreloadStore.store('invite_info', {
    invited_by: {"id":123,"username":"neil","avatar_template":"/user_avatar/localhost/neil/{size}/25_1.png","name":"Neil Lalonde","title":"team"},
    email: "invited@asdf.com",
    username: "invited"
  });

  visit("/invites/myvalidinvitetoken");
  andThen(() => {
    ok(exists("#new-account-username"), "shows the username input");
    equal(find("#new-account-username").val(), "invited", "username is prefilled");
    ok(exists("#new-account-password"), "shows the password input");
    not(exists('.invites-show .btn-primary:disabled'), 'submit is enabled');
  });

  fillIn("#new-account-username", 'a');
  andThen(() => {
    ok(exists(".username-input .bad"), "username is not valid");
    ok(exists('.invites-show .btn-primary:disabled'), 'submit is disabled');
  });

  fillIn("#new-account-password", 'aaa');
  andThen(() => {
    ok(exists(".password-input .bad"), "password is not valid");
    ok(exists('.invites-show .btn-primary:disabled'), 'submit is disabled');
  });

  fillIn("#new-account-username", 'validname');
  fillIn("#new-account-password", 'secur3ty4Y0uAndMe');
  andThen(() => {
    ok(exists(".username-input .good"), "username is valid");
    ok(exists(".password-input .good"), "password is valid");
    not(exists('.invites-show .btn-primary:disabled'), 'submit is enabled');
  });
});
