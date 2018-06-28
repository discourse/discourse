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

QUnit.test("update some fields", assert => {
  visit("/u/eviltrout/preferences");

  andThen(() => {
    assert.ok($("body.user-preferences-page").length, "has the body class");
    assert.equal(
      currentURL(),
      "/u/eviltrout/preferences/account",
      "defaults to account tab"
    );
    assert.ok(exists(".user-preferences"), "it shows the preferences");
  });

  const savePreferences = () => {
    click(".save-user");
    assert.ok(!exists(".saved-user"), "it hasn't been saved yet");
    andThen(() => {
      assert.ok(exists(".saved-user"), "it displays the saved message");
    });
  };

  fillIn(".pref-name input[type=text]", "Jon Snow");
  savePreferences();

  click(".preferences-nav .nav-profile a");
  fillIn("#edit-location", "Westeros");
  savePreferences();

  click(".preferences-nav .nav-emails a");
  click(".pref-activity-summary input[type=checkbox]");
  savePreferences();

  click(".preferences-nav .nav-notifications a");
  selectKit(".control-group.notifications .combo-box.duration")
    .expand()
    .selectRowByValue(1440);
  savePreferences();

  click(".preferences-nav .nav-categories a");
  fillIn(".category-controls .category-selector", "faq");
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

QUnit.test("username", assert => {
  visit("/u/eviltrout/preferences/username");
  andThen(() => {
    assert.ok(exists("#change_username"), "it has the input element");
  });
});

QUnit.test("about me", assert => {
  visit("/u/eviltrout/preferences/about-me");
  andThen(() => {
    assert.ok(exists(".raw-bio"), "it has the input element");
  });
});

QUnit.test("email", assert => {
  visit("/u/eviltrout/preferences/email");
  andThen(() => {
    assert.ok(exists("#change-email"), "it has the input element");
  });

  fillIn("#change-email", "invalidemail");

  andThen(() => {
    assert.equal(
      find(".tip.bad")
        .text()
        .trim(),
      I18n.t("user.email.invalid"),
      "it should display invalid email tip"
    );
  });
});

QUnit.test("second factor", assert => {
  visit("/u/eviltrout/preferences/second-factor");

  andThen(() => {
    assert.ok(exists("#password"), "it has a password input");
  });

  fillIn("#password", "secrets");
  click(".user-preferences .btn-primary");

  andThen(() => {
    assert.ok(exists("#test-qr"), "shows qr code");
    assert.notOk(exists("#password"), "it hides the password input");
  });

  fillIn("#second-factor-token", "111111");
  click(".btn-primary");

  andThen(() => {
    assert.ok(
      find(".alert-error")
        .html()
        .indexOf("invalid token") > -1,
      "shows server validation error message"
    );
  });
});

QUnit.test("second factor backup", assert => {
  visit("/u/eviltrout/preferences/second-factor-backup");

  andThen(() => {
    assert.ok(
      exists("#second-factor-token"),
      "it has a authentication token input"
    );
  });

  fillIn("#second-factor-token", "111111");
  click(".user-preferences .btn-primary");

  andThen(() => {
    assert.ok(exists(".backup-codes-area"), "shows backup codes");
  });
});

acceptance("User Preferences when badges are disabled", {
  loggedIn: true,
  settings: {
    enable_badges: false
  }
});

QUnit.test("visit my preferences", assert => {
  visit("/u/eviltrout/preferences");
  andThen(() => {
    assert.ok($("body.user-preferences-page").length, "has the body class");
    assert.equal(
      currentURL(),
      "/u/eviltrout/preferences/account",
      "defaults to account tab"
    );
    assert.ok(exists(".user-preferences"), "it shows the preferences");
  });
});
