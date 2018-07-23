import { acceptance } from "helpers/qunit-helpers";
acceptance("User Preferences", {
  loggedIn: true,
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.post("/u/second_factors.json", () => { //eslint-disable-line
      return response({
        key: "rcyryaqage3jexfj",
        qr: '<div id="test-qr">qr-code</div>'
      });
    });

    // prettier-ignore
    server.put("/u/second_factor.json", () => { //eslint-disable-line
      return response({ error: "invalid token" });
    });

    // prettier-ignore
    server.put("/u/second_factors_backup.json", () => { //eslint-disable-line
      return response({ backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"] });
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
    await click(".save-user");
    assert.ok(!exists(".saved-user"), "it hasn't been saved yet");
    assert.ok(exists(".saved-user"), "it displays the saved message");
  };

  await fillIn(".pref-name input[type=text]", "Jon Snow");
  savePreferences();

  await click(".preferences-nav .nav-profile a");
  await fillIn("#edit-location", "Westeros");
  savePreferences();

  await click(".preferences-nav .nav-emails a");
  await click(".pref-activity-summary input[type=checkbox]");
  savePreferences();

  await click(".preferences-nav .nav-notifications a");
  await selectKit(
    ".control-group.notifications .combo-box.duration"
  ).expandAwait();
  await selectKit(
    ".control-group.notifications .combo-box.duration"
  ).selectRowByValueAwait(1440);
  savePreferences();

  await click(".preferences-nav .nav-categories a");
  await fillIn(".category-controls .category-selector", "faq");
  savePreferences();

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
});

acceptance("Avatar selector when selectable avatars is enabled", {
  loggedIn: true,
  settings: { selectable_avatars_enabled: true },
  beforeEach() {
    // prettier-ignore
    server.get("/site/selectable-avatars.json", () => { //eslint-disable-line
      return [200, { "Content-Type": "application/json" }, [
        "https://www.discourse.org",
        "https://meta.discourse.org",
      ]];
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
