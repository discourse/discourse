import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Static", function () {
  test("Static Pages", async function (assert) {
    await visit("/faq");
    assert.ok(
      document.body.classList.contains("static-faq"),
      "has the body class"
    );
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/guidelines");
    assert.ok(
      document.body.classList.contains("static-guidelines"),
      "has the body class"
    );
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/conduct");
    assert.ok(
      document.body.classList.contains("static-conduct"),
      "has the body class"
    );
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/tos");
    assert.ok(
      document.body.classList.contains("static-tos"),
      "has the body class"
    );
    assert.ok(exists(".body-page"), "The content is present");

    await visit("/privacy");
    assert.ok(
      document.body.classList.contains("static-privacy"),
      "has the body class"
    );
    assert.ok(exists(".body-page"), "The content is present");

  test("Login redirect", async function (assert) {
    await visit("/login");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it redirects to /latest"
    );
  });

  test("Login-required page", async function (assert) {
    this.siteSettings.login_required = true;
    await visit("/login");

    assert.strictEqual(currentRouteName(), "login");
    assert.true(exists(".body-page"), "The content is present");
    // TODO: check the buttons
  });
    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it redirects them to latest unless `login_required`"
    );
  });
});
