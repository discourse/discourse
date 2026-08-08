import { getOwner } from "@ember/owner";
import { click, currentRouteName, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Read only mode - anonymous", function () {
  test("hides the sign up button for as long as read only mode lasts", async function (assert) {
    await visit("/");

    assert.dom("header .sign-up-button").exists("shows the sign up button");

    await publishToMessageBus("/site/read-only", true);

    assert
      .dom("header .sign-up-button")
      .doesNotExist("hides the sign up button");
    assert.dom("header .login-button").exists("keeps the log in button");
    assert
      .dom("#global-notice-alert-read-only .text")
      .hasText(
        i18n("read_only_mode.enabled_anonymous"),
        "tells anonymous visitors that signing up and logging in are unavailable"
      );

    await publishToMessageBus("/site/read-only", false);

    assert
      .dom("header .sign-up-button")
      .exists("shows the sign up button once read only mode ends");
  });

  test("keeps you where you are when you try to log in", async function (assert) {
    await visit("/");
    await publishToMessageBus("/site/read-only", true);

    await click("header .login-button");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "stays on the page you were on"
    );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("read_only_mode.login_disabled"),
        "explains why logging in is unavailable"
      );
  });

  test("redirects home when /login is opened directly", async function (assert) {
    getOwner(this).lookup("service:site").set("isReadOnly", true);

    await visit("/login");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "redirects to the homepage instead of rendering nothing"
    );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("read_only_mode.login_disabled"),
        "explains why logging in is unavailable"
      );
  });

  test("redirects home when /signup is opened directly", async function (assert) {
    getOwner(this).lookup("service:site").set("isReadOnly", true);

    await visit("/signup");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "redirects to the homepage instead of rendering nothing"
    );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("read_only_mode.signup_disabled"),
        "explains why signing up is unavailable"
      );
  });
});

acceptance("Staff writes only mode - anonymous", function (needs) {
  needs.pretender((server, helper) => {
    const readOnly = () =>
      helper.response(503, {
        errors: ["The site is in read only mode. Interactions are disabled."],
        error_type: "read_only",
      });

    server.post("/session", readOnly);
    server.post("/u/email-login", readOnly);
  });

  test("explains that only staff can sign up or log in", async function (assert) {
    getOwner(this).lookup("service:site").set("isStaffWritesOnly", true);

    await visit("/login");
    await publishToMessageBus("/site/read-only", true);

    assert
      .dom("#global-notice-alert-staff-writes-only .text")
      .hasText(
        i18n("staff_writes_only_mode.enabled_anonymous"),
        "tells anonymous visitors that only staff can log in"
      );
    assert
      .dom("#new-account-link")
      .doesNotExist("hides the create account link");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "correct");
    await click(".login-fullpage .btn-primary");

    assert
      .dom(".login-fullpage .alert-error")
      .hasText(
        i18n("staff_writes_only_mode.login_disabled"),
        "explains why a password login failed"
      );

    await click("#email-login-link");

    assert
      .dom(".login-fullpage .alert-error")
      .hasText(
        i18n("staff_writes_only_mode.login_disabled"),
        "explains why an email login link was refused"
      );
  });
});
