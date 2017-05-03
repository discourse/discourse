import { acceptance } from "helpers/qunit-helpers";
acceptance("User Preferences", { loggedIn: true });

test("update some fields", () => {
  visit("/u/eviltrout/preferences");

  andThen(() => {
    ok($('body.user-preferences-page').length, "has the body class");
    equal(currentURL(), '/u/eviltrout/preferences/account', "defaults to account tab");
    ok(exists('.user-preferences'), 'it shows the preferences');
  });

  const savePreferences = () => {
    click('.save-user');
    ok(!exists('.saved-user'), "it hasn't been saved yet");
    andThen(() => {
      ok(exists('.saved-user'), 'it displays the saved message');
    });
  };

  click(".preferences-nav .nav-profile a");
  fillIn("#edit-location", "Westeros");
  savePreferences();

  click(".preferences-nav .nav-emails a");
  click(".pref-activity-summary input[type=checkbox]");
  savePreferences();

  click(".preferences-nav .nav-notifications a");
  selectDropdown('.control-group.notifications select.combobox', 1440);
  savePreferences();

  click(".preferences-nav .nav-categories a");
  fillIn('.category-controls .category-selector', 'faq');
  savePreferences();

  ok(!exists('.preferences-nav .nav-tags a'), "tags tab isn't there when tags are disabled");

  // Error: Unhandled request in test environment: /themes/assets/10d71596-7e4e-4dc0-b368-faa3b6f1ce6d?_=1493833562388 (GET)
  // click(".preferences-nav .nav-interface a");
  // click('.control-group.other input[type=checkbox]:first');
  // savePreferences();

  ok(!exists('.preferences-nav .nav-apps a'), "apps tab isn't there when you have no authorized apps");
});

test("username", () => {
  visit("/u/eviltrout/preferences/username");
  andThen(() => {
    ok(exists("#change_username"), "it has the input element");
  });
});

test("about me", () => {
  visit("/u/eviltrout/preferences/about-me");
  andThen(() => {
    ok(exists(".raw-bio"), "it has the input element");
  });
});

test("email", () => {
  visit("/u/eviltrout/preferences/email");
  andThen(() => {
    ok(exists("#change-email"), "it has the input element");
  });

  fillIn("#change-email", 'invalidemail');

  andThen(() => {
    equal(find('.tip.bad').text().trim(), I18n.t('user.email.invalid'), 'it should display invalid email tip');
  });
});
