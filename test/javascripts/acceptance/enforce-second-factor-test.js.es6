import { acceptance, updateCurrentUser } from "helpers/qunit-helpers";

acceptance("Enforce Second Factor", {
  loggedIn: true,
  pretend(server, helper) {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        password_required: "true"
      });
    });
  }
});

QUnit.test("as an admin", async assert => {
  await visit("/u/eviltrout/preferences/second-factor");
  Discourse.SiteSettings.enforce_second_factor = "staff";

  await visit("/u/eviltrout/summary");

  assert.equal(
    find(".control-label").text(),
    "Password",
    "it will not transition from second-factor preferences"
  );

  await click("#toggle-hamburger-menu");
  await click("a.admin-link");

  assert.equal(
    find(".control-label").text(),
    "Password",
    "it stays at second-factor preferences"
  );
});

QUnit.test("as a user", async assert => {
  updateCurrentUser({ moderator: false, admin: false });

  await visit("/u/eviltrout/preferences/second-factor");
  Discourse.SiteSettings.enforce_second_factor = "all";

  await visit("/u/eviltrout/summary");

  assert.equal(
    find(".control-label").text(),
    "Password",
    "it will not transition from second-factor preferences"
  );

  await click("#toggle-hamburger-menu");
  await click("a.about-link");

  assert.equal(
    find(".control-label").text(),
    "Password",
    "it stays at second-factor preferences"
  );
});

QUnit.test("as an anonymous user", async assert => {
  updateCurrentUser({ moderator: false, admin: false, is_anonymous: true });

  await visit("/u/eviltrout/preferences/second-factor");
  Discourse.SiteSettings.enforce_second_factor = "all";
  Discourse.SiteSettings.allow_anonymous_posting = true;

  await visit("/u/eviltrout/summary");

  assert.notEqual(
    find(".control-label").text(),
    "Password",
    "it will transition from second-factor preferences"
  );

  await click("#toggle-hamburger-menu");
  await click("a.about-link");

  assert.notEqual(
    find(".control-label").text(),
    "Password",
    "it is possible to navigate to other pages"
  );
});
