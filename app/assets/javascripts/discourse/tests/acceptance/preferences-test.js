import {
  acceptance,
  count,
  exists,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  currentRouteName,
  currentURL,
  fillIn,
  visit,
} from "@ember/test-helpers";
import I18n from "I18n";
import User from "discourse/models/user";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

function preferencesPretender(server, helper) {
  server.post("/u/second_factors.json", () => {
    return helper.response({
      success: "OK",
      password_required: "true",
    });
  });

  server.post("/u/create_second_factor_totp.json", () => {
    return helper.response({
      key: "rcyryaqage3jexfj",
      qr: "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=",
    });
  });

  server.post("/u/create_second_factor_security_key.json", () => {
    return helper.response({
      challenge: "a6d393d12654c130b2273e68ca25ca232d1d7f4c2464c2610fb8710a89d4",
      rp_id: "localhost",
      rp_name: "Discourse",
      supported_algorithms: [-7, -257],
    });
  });

  server.post("/u/enable_second_factor_totp.json", () => {
    return helper.response({ error: "invalid token" });
  });

  server.put("/u/second_factors_backup.json", () => {
    return helper.response({
      backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"],
    });
  });

  server.post("/u/eviltrout/preferences/revoke-account", () => {
    return helper.response({
      success: true,
    });
  });

  server.put("/u/eviltrout/preferences/email", () => {
    return helper.response({
      success: true,
    });
  });

  server.post("/user_avatar/eviltrout/refresh_gravatar.json", () => {
    return helper.response({
      gravatar_upload_id: 6543,
      gravatar_avatar_template: "/images/avatar.png",
    });
  });

  server.get("/u/eviltrout/activity.json", () => {
    return helper.response({});
  });
}

acceptance("User Preferences", function (needs) {
  needs.user();
  needs.pretender(preferencesPretender);
  test("update some fields", async function (assert) {
    await visit("/u/eviltrout/preferences");

    assert.ok($("body.user-preferences-page").length, "has the body class");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/account",
      "defaults to account tab"
    );
    assert.ok(exists(".user-preferences"), "it shows the preferences");

    const savePreferences = async () => {
      assert.ok(!exists(".saved"), "it hasn't been saved yet");
      await click(".save-changes");
      assert.ok(exists(".saved"), "it displays the saved message");
      queryAll(".saved").remove();
    };

    await fillIn(".pref-name input[type=text]", "Jon Snow");
    await savePreferences();

    await click(".preferences-nav .nav-profile a");
    await fillIn("#edit-location", "Westeros");
    await savePreferences();

    await click(".preferences-nav .nav-emails a");
    await click(".pref-activity-summary input[type=checkbox]");
    await savePreferences();

    await click(".preferences-nav .nav-notifications a");
    await selectKit(
      ".control-group.notifications .combo-box.duration"
    ).expand();
    await selectKit(
      ".control-group.notifications .combo-box.duration"
    ).selectRowByValue(1440);
    await savePreferences();

    await click(".preferences-nav .nav-categories a");
    const categorySelector = selectKit(
      ".tracking-controls .category-selector "
    );
    await categorySelector.expand();
    await categorySelector.fillInFilter("faq");
    await savePreferences();

    assert.ok(
      !exists(".preferences-nav .nav-tags a"),
      "tags tab isn't there when tags are disabled"
    );

    await click(".preferences-nav .nav-interface a");
    await click(".control-group.other input[type=checkbox]:nth-of-type(1)");
    await savePreferences();

    assert.ok(
      !exists(".preferences-nav .nav-apps a"),
      "apps tab isn't there when you have no authorized apps"
    );
  });

  test("username", async function (assert) {
    await visit("/u/eviltrout/preferences/username");
    assert.ok(exists("#change_username"), "it has the input element");
  });

  test("email", async function (assert) {
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");

    await fillIn("#change-email", "invalidemail");

    assert.strictEqual(
      queryAll(".tip.bad").text().trim(),
      I18n.t("user.email.invalid"),
      "it should display invalid email tip"
    );
  });

  test("email field always shows up", async function (assert) {
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");

    await fillIn("#change-email", "eviltrout@discourse.org");
    await click(".user-preferences button.btn-primary");

    await visit("/u/eviltrout/preferences");
    await visit("/u/eviltrout/preferences/email");

    assert.ok(exists("#change-email"), "it has the input element");
  });

  test("connected accounts", async function (assert) {
    await visit("/u/eviltrout/preferences/account");

    assert.ok(
      exists(".pref-associated-accounts"),
      "it has the connected accounts section"
    );
    assert.ok(
      queryAll(
        ".pref-associated-accounts table tr:nth-of-type(1) td:nth-of-type(1)"
      )
        .html()
        .indexOf("Facebook") > -1,
      "it lists facebook"
    );

    await click(
      ".pref-associated-accounts table tr:nth-of-type(1) td:last-child button"
    );

    queryAll(".pref-associated-accounts table tr:nth-of-type(1) td:last button")
      .html()
      .indexOf("Connect") > -1;
  });

  test("second factor totp", async function (assert) {
    await visit("/u/eviltrout/preferences/second-factor");

    assert.ok(exists("#password"), "it has a password input");

    await fillIn("#password", "secrets");
    await click(".user-preferences .btn-primary");
    assert.notOk(exists("#password"), "it hides the password input");

    await click(".new-totp");
    assert.ok(exists(".qr-code img"), "shows qr code image");

    await click(".add-totp");

    assert.ok(
      queryAll(".alert-error").html().indexOf("provide a name and the code") >
        -1,
      "shows name/token missing error message"
    );
  });

  test("second factor security keys", async function (assert) {
    await visit("/u/eviltrout/preferences/second-factor");

    assert.ok(exists("#password"), "it has a password input");

    await fillIn("#password", "secrets");
    await click(".user-preferences .btn-primary");
    assert.notOk(exists("#password"), "it hides the password input");

    await click(".new-security-key");
    assert.ok(exists("#security-key-name"), "shows security key name input");

    fillIn("#security-key-name", "");

    // The following tests can only run when Webauthn is enabled. This is not
    // always the case, for example on a browser running on a non-standard port
    if (typeof PublicKeyCredential !== "undefined") {
      await click(".add-security-key");

      assert.ok(
        queryAll(".alert-error").html().indexOf("provide a name") > -1,
        "shows name missing error message"
      );
    }
  });

  test("default avatar selector", async function (assert) {
    await visit("/u/eviltrout/preferences");

    await click(".pref-avatar .btn");
    assert.ok(exists(".avatar-choice", "opens the avatar selection modal"));

    await click(".avatar-selector-refresh-gravatar");

    assert.strictEqual(
      User.currentProp("gravatar_avatar_upload_id"),
      6543,
      "it should set the gravatar_avatar_upload_id property"
    );
  });
});

acceptance("Second Factor Backups", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        totps: [{ id: 1, name: "one of them" }],
      });
    });

    server.put("/u/second_factors_backup.json", () => {
      return helper.response({
        backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"],
      });
    });

    server.get("/u/eviltrout/activity.json", () => {
      return helper.response({});
    });
  });

  test("second factor backup", async function (assert) {
    updateCurrentUser({ second_factor_enabled: true });
    await visit("/u/eviltrout/preferences/second-factor");
    await click(".edit-2fa-backup");
    assert.ok(
      exists(".second-factor-backup-preferences"),
      "shows the 2fa backup panel"
    );
    await click(".second-factor-backup-preferences .btn-primary");

    assert.ok(exists(".backup-codes-area"), "shows backup codes");
  });
});

acceptance(
  "Avatar selector when selectable avatars is enabled",
  function (needs) {
    needs.user();
    needs.settings({ selectable_avatars_enabled: true });
    needs.pretender((server, helper) => {
      server.get("/site/selectable-avatars.json", () =>
        helper.response([
          "https://www.discourse.org",
          "https://meta.discourse.org",
        ])
      );
    });

    test("selectable avatars", async function (assert) {
      await visit("/u/eviltrout/preferences");
      await click(".pref-avatar .btn");
      assert.ok(
        exists(".selectable-avatars", "opens the avatar selection modal")
      );
    });
  }
);

acceptance("User Preferences when badges are disabled", function (needs) {
  needs.user();
  needs.settings({ enable_badges: false });
  needs.pretender(preferencesPretender);

  test("visit my preferences", async function (assert) {
    await visit("/u/eviltrout/preferences");
    assert.ok($("body.user-preferences-page").length, "has the body class");
    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/account",
      "defaults to account tab"
    );
    assert.ok(exists(".user-preferences"), "it shows the preferences");
  });
});

acceptance(
  "User can select a topic to feature on profile if site setting in enabled",
  function (needs) {
    needs.user();
    needs.settings({ allow_featured_topic_on_user_profiles: true });
    needs.pretender((server, helper) => {
      server.put("/u/eviltrout/feature-topic", () => {
        return helper.response({
          success: true,
        });
      });
    });

    test("setting featured topic on profile", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert.ok(
        !exists(".featured-topic-link"),
        "no featured topic link to present"
      );
      assert.ok(
        !exists(".clear-feature-topic-on-profile-btn"),
        "clear button not present"
      );

      const selectTopicBtn = queryAll(
        ".feature-topic-on-profile-btn:nth-of-type(1)"
      )[0];
      assert.ok(exists(selectTopicBtn), "feature topic button is present");

      await click(selectTopicBtn);

      assert.ok(
        exists(".feature-topic-on-profile"),
        "topic picker modal is open"
      );

      const topicRadioBtn = queryAll(
        'input[name="choose_topic_id"]:nth-of-type(1)'
      )[0];
      assert.ok(exists(topicRadioBtn), "Topic options are prefilled");
      await click(topicRadioBtn);

      await click(".save-featured-topic-on-profile");

      assert.ok(
        exists(".featured-topic-link"),
        "link to featured topic is present"
      );
      assert.ok(
        exists(".clear-feature-topic-on-profile-btn"),
        "clear button is present"
      );
    });
  }
);

acceptance("Custom User Fields", function (needs) {
  needs.user();
  needs.site({
    user_fields: [
      {
        id: 30,
        name: "What kind of pet do you have?",
        field_type: "dropdown",
        options: ["Dog", "Cat", "Hamster"],
        required: true,
      },
    ],
  });
  needs.pretender(preferencesPretender);

  test("can select an option from a dropdown", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    assert.ok(exists(".user-field"), "it has at least one user field");
    await click(".user-field.dropdown");

    const field = selectKit(
      ".user-field-what-kind-of-pet-do-you-have .combo-box"
    );
    await field.expand();
    await field.selectRowByValue("Cat");
    assert.strictEqual(
      field.header().value(),
      "Cat",
      "it sets the value of the field"
    );
  });
});

acceptance(
  "User Preferences, selecting bookmarks discovery as user's default homepage",
  function (needs) {
    needs.user();
    needs.settings({
      top_menu: "categories|latest|top|bookmarks",
    });

    test("selecting bookmarks as home directs home to bookmarks", async function (assert) {
      await visit("/u/eviltrout/preferences/interface");
      assert.ok(exists(".home .combo-box"), "it has a home selector combo-box");

      const field = selectKit(".home .combo-box");
      await field.expand();
      await field.selectRowByValue("6");
      await click(".save-changes");
      await visit("/");
      assert.ok(exists(".topic-list"), "The list of topics was rendered");
      assert.strictEqual(
        currentRouteName(),
        "discovery.bookmarks",
        "it navigates to bookmarks"
      );
    });
  }
);

acceptance("Ignored users", function (needs) {
  needs.user();
  needs.settings({ min_trust_level_to_allow_ignore: 1 });

  test("when trust level < min level to ignore", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    await updateCurrentUser({ trust_level: 0, moderator: false, admin: false });

    assert.ok(
      !exists(".user-ignore"),
      "it does not show the list of ignored users"
    );
  });

  test("when trust level >= min level to ignore", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    await updateCurrentUser({ trust_level: 1 });
    assert.ok(exists(".user-ignore"), "it shows the list of ignored users");
  });

  test("staff can always see ignored users", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    await updateCurrentUser({ moderator: true });
    assert.ok(exists(".user-ignore"), "it shows the list of ignored users");
  });
});

acceptance("Security", function (needs) {
  needs.user();
  needs.pretender(preferencesPretender);

  test("recently connected devices", async function (assert) {
    await visit("/u/eviltrout/preferences/security");

    assert.strictEqual(
      queryAll(".auth-tokens > .auth-token:nth-of-type(1) .auth-token-device")
        .text()
        .trim(),
      "Linux Computer",
      "it should display active token first"
    );

    assert.strictEqual(
      queryAll(".pref-auth-tokens > a:nth-of-type(1)").text().trim(),
      I18n.t("user.auth_tokens.show_all", { count: 3 }),
      "it should display two tokens"
    );
    assert.strictEqual(
      count(".pref-auth-tokens .auth-token"),
      2,
      "it should display two tokens"
    );

    await click(".pref-auth-tokens > a:nth-of-type(1)");

    assert.strictEqual(
      count(".pref-auth-tokens .auth-token"),
      3,
      "it should display three tokens"
    );

    const authTokenDropdown = selectKit(".auth-token-dropdown");
    await authTokenDropdown.expand();
    await authTokenDropdown.selectRowByValue("notYou");

    assert.strictEqual(count(".d-modal:visible"), 1, "modal should appear");

    await click(".modal-footer .btn-primary");

    assert.strictEqual(
      count(".pref-password.highlighted"),
      1,
      "it should highlight password preferences"
    );
  });
});

acceptance(
  "User Preferences for staged user and don't allow tracking prefs",
  function (needs) {
    needs.settings({
      allow_changing_staged_user_tracking: false,
      tagging_enabled: true,
    });
    needs.pretender(preferencesPretender);

    test("staged user doesn't show category and tag preferences", async function (assert) {
      await visit("/u/staged/preferences");

      assert.ok($("body.user-preferences-page").length, "has the body class");
      assert.strictEqual(
        currentURL(),
        "/u/staged/preferences/account",
        "defaults to account tab"
      );
      assert.ok(exists(".user-preferences"), "it shows the preferences");

      assert.ok(
        !exists(".preferences-nav .nav-categories a"),
        "categories tab isn't there for staged users"
      );

      assert.ok(
        !exists(".preferences-nav .nav-tags a"),
        "tags tab isn't there for staged users"
      );
    });
  }
);
