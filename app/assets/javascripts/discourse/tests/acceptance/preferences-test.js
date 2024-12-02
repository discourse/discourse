import {
  click,
  currentRouteName,
  currentURL,
  fillIn,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function preferencesPretender(server, helper) {
  server.post("/u/create_second_factor_totp.json", () => {
    return helper.response({
      key: "rcyryaqage3jexfj",
      qr: "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=",
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
}

acceptance("User Preferences", function (needs) {
  needs.user();
  needs.pretender(preferencesPretender);

  test("update some fields", async function (assert) {
    await visit("/u/eviltrout/preferences");

    assert
      .dom(document.body)
      .hasClass("user-preferences-page", "has the body class");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/account",
      "defaults to account tab"
    );

    assert.dom(".user-preferences").exists("it shows the preferences");

    const savePreferences = async () => {
      assert.dom(".saved").doesNotExist("it hasn't been saved yet");
      await click(".save-changes");
      assert.dom(".saved").exists("it displays the saved message");
      document.querySelector(".saved").remove();
    };

    await fillIn(".pref-name input[type=text]", "Jon Snow");
    await savePreferences();

    await click(".user-nav__preferences-profile a");
    await fillIn("#edit-location", "Westeros");
    await savePreferences();

    await click(".user-nav__preferences-emails a");
    await click(".pref-activity-summary input[type=checkbox]");
    await savePreferences();

    await click(".user-nav__preferences-tracking a");

    await selectKit(
      ".user-preferences_tracking-topics-controls .combo-box.duration"
    ).expand();

    await selectKit(
      ".user-preferences_tracking-topics-controls .combo-box.duration"
    ).selectRowByValue(1440);

    await savePreferences();

    await click(".user-nav__preferences-tracking a");

    const categorySelector = selectKit(
      ".tracking-controls .category-selector "
    );

    await categorySelector.expand();
    await categorySelector.fillInFilter("faq");

    const tagSelector = selectKit(".tracking-controls .tag-chooser");
    await tagSelector.expand();
    await tagSelector.fillInFilter("monkey");

    await savePreferences();

    this.siteSettings.tagging_enabled = false;

    await visit("/u/eviltrout/preferences/tracking");

    assert
      .dom(".tag-notifications")
      .doesNotExist(
        "updating tags tracking preferences isn't visible when tags are disabled"
      );

    await click(".user-nav__preferences-interface a");
    await click(".control-group.other input[type=checkbox]:nth-of-type(1)");
    await savePreferences();
  });
});

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
    assert.dom(".user-field").exists("it has at least one user field");
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
      assert.dom(".home .combo-box").exists("it has a home selector combo-box");

      const field = selectKit(".home .combo-box");
      await field.expand();
      await field.selectRowByValue("6");
      await click(".save-changes");
      await visit("/");
      assert.dom(".topic-list").exists("The list of topics was rendered");
      assert.strictEqual(
        currentRouteName(),
        "discovery.bookmarks",
        "it navigates to bookmarks"
      );
    });
  }
);

acceptance("Ignored users", function (needs) {
  needs.user({ can_ignore_users: true });

  test("when user is not allowed to ignore", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    updateCurrentUser({
      trust_level: 0,
      moderator: false,
      admin: false,
      can_ignore_users: false,
      groups: [
        {
          id: 10,
          name: "trust_level_0",
          display_name: "trust_level_0",
          automatic: true,
        },
      ],
    });

    assert
      .dom(".user-ignore")
      .doesNotExist("it does not show the list of ignored users");
  });

  test("when user is allowed to ignore", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    updateCurrentUser({ can_ignore_users: true });
    assert.dom(".user-ignore").exists("it shows the list of ignored users");
  });

  test("staff can always see ignored users", async function (assert) {
    await visit(`/u/eviltrout/preferences/users`);
    updateCurrentUser({ moderator: true });
    assert.dom(".user-ignore").exists("it shows the list of ignored users");
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

      assert
        .dom(document.body)
        .hasClass("user-preferences-page", "has the body class");
      assert.strictEqual(
        currentURL(),
        "/u/staged/preferences/account",
        "defaults to account tab"
      );
      assert.dom(".user-preferences").exists("it shows the preferences");

      assert
        .dom(".preferences-nav .nav-categories a")
        .doesNotExist("categories tab isn't there for staged users");

      assert
        .dom(".preferences-nav .nav-tags a")
        .doesNotExist("tags tab isn't there for staged users");
    });
  }
);

acceptance("User Preference - No Secondary Emails Allowed", function (needs) {
  needs.user();
  needs.pretender(preferencesPretender);
  needs.settings({ max_allowed_secondary_emails: 0 });

  test("Add Alternate Email Button is unavailable", async function (assert) {
    await visit("/u/eviltrout/preferences");

    assert.dom(".pref-email a").doesNotExist();
  });
});
