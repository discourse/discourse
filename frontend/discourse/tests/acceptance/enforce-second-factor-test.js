import {
  click,
  currentRouteName,
  currentURL,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
        unconfirmed_session: true,
      });
    });
  });

  test("required users can confirm a local credential directly on the enrollment page", async function (assert) {
    this.siteSettings.enforce_second_factor = "staff";
    await visit("/u/eviltrout/preferences/second-factor");

    assert.strictEqual(
      currentRouteName(),
      "preferences.second-factor",
      "does not try to redirect a required user to security preferences"
    );
    assert.dom(".new-totp").doesNotExist("requires confirmation first");
    assert.dom(".second-factor .cancel").doesNotExist("must enroll to leave");
    await click(".second-factor .btn-primary");
    assert.dom(".confirm-session").exists("opens local confirmation");
  });

  test("as an anonymous user", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, is_anonymous: true });

    await visit("/u/eviltrout/preferences/second-factor");
    this.siteSettings.enforce_second_factor = "all";
    this.siteSettings.allow_anonymous_mode = true;

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

acceptance("Required enrollment", function (needs) {
  needs.user({ moderator: false, admin: false });
  needs.settings({ enforce_second_factor: "all" });
  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () =>
      helper.response({ success: "OK", totps: [], security_keys: [] })
    );
  });

  for (const loginMethod of ["local", "oauth"]) {
    test(`requires enrollment after ${loginMethod} login`, async function (assert) {
      updateCurrentUser({ login_method: loginMethod });
      await visit("/u/eviltrout/preferences/second-factor");
      await click(".home-logo-wrapper-outlet a");

      assert.strictEqual(
        currentRouteName(),
        "preferences.second-factor",
        "requires enrollment before leaving preferences"
      );
    });
  }

  test("a required user is routed to their own enrollment page", async function (assert) {
    await visit("/u/charlie/preferences/second-factor");

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/preferences/second-factor",
      "does not manage the current user's factors under another profile"
    );
  });

  test("an enrolled user can leave factor preferences without disabling all factors", async function (assert) {
    updateCurrentUser({ second_factor_enabled: true });
    pretender.post("/u/second_factors.json", () =>
      response({ success: "OK", totps: [{ id: 1 }], security_keys: [] })
    );
    await visit("/u/eviltrout/preferences/second-factor");

    assert.dom(".new-totp").exists("allows managing existing enrollment");
    assert.dom(".alert-error").doesNotExist("does not ask them to enroll");
    assert
      .dom(".pref-second-factor-disable-all")
      .doesNotExist("cannot disable all factors while enrollment is required");

    await click(".second-factor .cancel");
    assert.strictEqual(
      currentRouteName(),
      "preferences.security",
      "can return to security preferences"
    );
  });
});
