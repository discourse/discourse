import { acceptance } from "helpers/qunit-helpers";
import User from "discourse/models/user";

acceptance("User Preferences", {
  loggedIn: true,
  pretend(server, helper) {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        key: "rcyryaqage3jexfj",
        qr: '<div id="test-qr">qr-code</div>'
      });
    });

    server.put("/u/second_factor.json", () => {
      return helper.response({ error: "invalid token" });
    });

    server.put("/u/second_factors_backup.json", () => {
      return helper.response({
        backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"]
      });
    });

    server.post("/u/eviltrout/preferences/revoke-account", () => {
      return helper.response({
        success: true
      });
    });

    server.put("/u/eviltrout/preferences/email", () => {
      return helper.response({
        success: true
      });
    });

    server.post("/user_avatar/eviltrout/refresh_gravatar.json", () => {
      return helper.response({
        gravatar_upload_id: 6543,
        gravatar_avatar_template: "something"
      });
    });

    server.get("/u/eviltrout/activity.json", () => {
      return helper.response({});
    });
  }
});

QUnit.test("update some fields", async assert => {
  await visit("/u/eviltrout/preferences");

  assert.ok($("body.user-preferences-page").length, "has the body class");
  assert.equal(
    currentURL(),
    "/u/eviltrout/preferences/account",
    "defaults to account tab"
  );
  assert.ok(exists(".user-preferences"), "it shows the preferences");

  const savePreferences = async () => {
    assert.ok(!exists(".saved-user"), "it hasn't been saved yet");
    await click(".save-user");
    assert.ok(exists(".saved-user"), "it displays the saved message");
    find(".saved-user").remove();
  };

  fillIn(".pref-name input[type=text]", "Jon Snow");
  await savePreferences();

  click(".preferences-nav .nav-profile a");
  fillIn("#edit-location", "Westeros");
  await savePreferences();

  click(".preferences-nav .nav-emails a");
  click(".pref-activity-summary input[type=checkbox]");
  await savePreferences();

  click(".preferences-nav .nav-notifications a");
  await selectKit(".control-group.notifications .combo-box.duration").expand();
  await selectKit(
    ".control-group.notifications .combo-box.duration"
  ).selectRowByValue(1440);
  await savePreferences();

  click(".preferences-nav .nav-categories a");
  fillIn(".category-controls .category-selector", "faq");
  await savePreferences();

  assert.ok(
    !exists(".preferences-nav .nav-tags a"),
    "tags tab isn't there when tags are disabled"
  );

  // Error: Unhandled request in test environment: /themes/assets/10d71596-7e4e-4dc0-b368-faa3b6f1ce6d?_=1493833562388 (GET)
  // click(".preferences-nav .nav-interface a");
  // click('.control-group.other input[type=checkbox]:first');
  // savePreferences();

  assert.ok(
    !exists(".preferences-nav .nav-apps a"),
    "apps tab isn't there when you have no authorized apps"
  );
});

QUnit.test("username", async assert => {
  await visit("/u/eviltrout/preferences/username");
  assert.ok(exists("#change_username"), "it has the input element");
});

QUnit.test("about me", async assert => {
  await visit("/u/eviltrout/preferences/about-me");
  assert.ok(exists(".raw-bio"), "it has the input element");
});

QUnit.test("email", async assert => {
  await visit("/u/eviltrout/preferences/email");

  assert.ok(exists("#change-email"), "it has the input element");

  await fillIn("#change-email", "invalidemail");

  assert.equal(
    find(".tip.bad")
      .text()
      .trim(),
    I18n.t("user.email.invalid"),
    "it should display invalid email tip"
  );
});

QUnit.test("email field always shows up", async assert => {
  await visit("/u/eviltrout/preferences/email");

  assert.ok(exists("#change-email"), "it has the input element");

  await fillIn("#change-email", "eviltrout@discourse.org");
  await click(".user-preferences button.btn-primary");

  await visit("/u/eviltrout/preferences");
  await visit("/u/eviltrout/preferences/email");

  assert.ok(exists("#change-email"), "it has the input element");
});

QUnit.test("connected accounts", async assert => {
  await visit("/u/eviltrout/preferences/account");

  assert.ok(
    exists(".pref-associated-accounts"),
    "it has the connected accounts section"
  );
  assert.ok(
    find(".pref-associated-accounts table tr:first td:first")
      .html()
      .indexOf("Facebook") > -1,
    "it lists facebook"
  );

  await click(".pref-associated-accounts table tr:first td:last button");

  find(".pref-associated-accounts table tr:first td:last button")
    .html()
    .indexOf("Connect") > -1;
});

QUnit.test("second factor", async assert => {
  await visit("/u/eviltrout/preferences/second-factor");

  assert.ok(exists("#password"), "it has a password input");

  await fillIn("#password", "secrets");
  await click(".user-preferences .btn-primary");

  assert.ok(exists("#test-qr"), "shows qr code");
  assert.notOk(exists("#password"), "it hides the password input");

  await fillIn("#second-factor-token", "111111");
  await click(".btn-primary");

  assert.ok(
    find(".alert-error")
      .html()
      .indexOf("invalid token") > -1,
    "shows server validation error message"
  );
});

QUnit.test("second factor backup", async assert => {
  await visit("/u/eviltrout/preferences/second-factor-backup");

  assert.ok(
    exists("#second-factor-token"),
    "it has a authentication token input"
  );

  await fillIn("#second-factor-token", "111111");
  await click(".user-preferences .btn-primary");

  assert.ok(exists(".backup-codes-area"), "shows backup codes");
});

QUnit.test("default avatar selector", async assert => {
  await visit("/u/eviltrout/preferences");

  await click(".pref-avatar .btn");
  assert.ok(exists(".avatar-choice", "opens the avatar selection modal"));

  await click(".avatar-selector-refresh-gravatar");

  assert.equal(
    User.currentProp("gravatar_avatar_upload_id"),
    6543,
    "it should set the gravatar_avatar_upload_id property"
  );
});

acceptance("Avatar selector when selectable avatars is enabled", {
  loggedIn: true,
  settings: { selectable_avatars_enabled: true },
  pretend(server) {
    server.get("/site/selectable-avatars.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        ["https://www.discourse.org", "https://meta.discourse.org"]
      ];
    });
  }
});

QUnit.test("selectable avatars", async assert => {
  await visit("/u/eviltrout/preferences");

  await click(".pref-avatar .btn");

  assert.ok(exists(".selectable-avatars", "opens the avatar selection modal"));
});

acceptance("User Preferences when badges are disabled", {
  loggedIn: true,
  settings: { enable_badges: false }
});

QUnit.test("visit my preferences", async assert => {
  await visit("/u/eviltrout/preferences");
  assert.ok($("body.user-preferences-page").length, "has the body class");
  assert.equal(
    currentURL(),
    "/u/eviltrout/preferences/account",
    "defaults to account tab"
  );
  assert.ok(exists(".user-preferences"), "it shows the preferences");
});

QUnit.test("recently connected devices", async assert => {
  await visit("/u/eviltrout/preferences");

  assert.equal(
    find(".pref-auth-tokens > a:first")
      .text()
      .trim(),
    I18n.t("user.auth_tokens.show_all", { count: 3 }),
    "it should display two tokens"
  );
  assert.ok(
    find(".pref-auth-tokens .auth-token").length === 2,
    "it should display two tokens"
  );

  await click(".pref-auth-tokens > a:first");

  assert.ok(
    find(".pref-auth-tokens .auth-token").length === 3,
    "it should display three tokens"
  );

  await click(".auth-token-dropdown:first button");
  await click("li[data-value='notYou']");

  assert.ok(find(".d-modal:visible").length === 1, "modal should appear");

  await click(".modal-footer .btn-primary");

  assert.ok(
    find(".pref-password.highlighted").length === 1,
    "it should highlight password preferences"
  );
});
