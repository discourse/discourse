import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

async function catchAbortedTransition() {
  try {
    await visit("/u/eviltrout/summary");
  } catch (e) {
    if (e.message !== "TransitionAborted") {
      throw e;
    }
  }
}

acceptance("Enforce Second Factor for unconfirmed session", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        unconfirmed_session: "true",
      });
    });
  });

  test("as an admin", async function (assert) {
    await visit("/u/eviltrout/preferences/second-factor");
    this.siteSettings.enforce_second_factor = "staff";

    assert.strictEqual(
      currentRouteName(),
      "preferences.security",
      "it transitions to security preferences"
    );
  });

  test("as a user", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/u/eviltrout/preferences/second-factor");
    this.siteSettings.enforce_second_factor = "all";

    assert.strictEqual(
      currentRouteName(),
      "preferences.security",
      "it will transition to security preferences"
    );
  });

  test("as an anonymous user", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, is_anonymous: true });

    await visit("/u/eviltrout/preferences/second-factor");
    this.siteSettings.enforce_second_factor = "all";
    this.siteSettings.allow_anonymous_posting = true;

    await catchAbortedTransition();

    assert.strictEqual(
      currentRouteName(),
      "user.summary",
      "it will transition from second-factor preferences"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    );

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='about']"
    );

    assert.strictEqual(
      currentRouteName(),
      "about",
      "it is possible to navigate to other pages"
    );
  });
});

acceptance("Enforce second factor for OAuth logins", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        unconfirmed_session: "true",
      });
    });
  });

  test("as a user using local login (username + password) when enforce_second_factor_on_external_auth is false", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      login_method: "local",
    });
    this.siteSettings.enforce_second_factor = "all";
    this.siteSettings.enforce_second_factor_on_external_auth = false;

    await visit("/u/eviltrout/preferences/second-factor");
    await click(".home-logo-wrapper-outlet a");

    assert.strictEqual(
      currentRouteName(),
      "preferences.second-factor",
      "it does not let the user leave the second factor preferences"
    );
  });

  test("as a user using oauth login when enforce_second_factor_on_external_auth is false", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      login_method: "oauth",
    });
    this.siteSettings.enforce_second_factor = "all";
    this.siteSettings.enforce_second_factor_on_external_auth = false;

    await visit("/u/eviltrout/preferences/second-factor");
    await click(".home-logo-wrapper-outlet a");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it does let the user leave the second factor preferences"
    );
  });
});
