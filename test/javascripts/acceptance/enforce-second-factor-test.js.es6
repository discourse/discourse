import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Enforce Second Factor", {
  loggedIn: true
});

QUnit.test("as an admin", async assert => {
  await visit("/u/eviltrout/preferences/second-factor");
  Discourse.SiteSettings.enforce_second_factor = "staff";

  await visit("/u/eviltrout/summary");
  assert.equal(
    $(".user-preferences h3").text(),
    I18n.t("user.second_factor.title"),
    "it will not transition from second-factor preferences"
  );

  await click("#toggle-hamburger-menu");
  await click("a.admin-link");

  assert.equal(
    $(".user-preferences h3").text(),
    I18n.t("user.second_factor.title"),
    "it stays at second-factor preferences"
  );
});

QUnit.test("as a user", async assert => {
  replaceCurrentUser({ staff: false, admin: false });

  await visit("/u/eviltrout/preferences/second-factor");
  Discourse.SiteSettings.enforce_second_factor = "all";

  await visit("/u/eviltrout/summary");
  assert.equal(
    $(".user-preferences h3").text(),
    I18n.t("user.second_factor.title"),
    "it will not transition from second-factor preferences"
  );

  await click("#toggle-hamburger-menu");
  await click("a.about-link");

  assert.equal(
    $(".user-preferences h3").text(),
    I18n.t("user.second_factor.title"),
    "it stays at second-factor preferences"
  );
});
