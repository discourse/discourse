import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Static", function () {
  test("Static Pages", async function (assert) {
    await visit("/faq");
    assert.true(
      document.body.classList.contains("static-faq"),
      "has the body class"
    );
    assert.true(exists(".body-page"), "The content is present");

    await visit("/guidelines");
    assert.true(
      document.body.classList.contains("static-guidelines"),
      "has the body class"
    );
    assert.true(exists(".body-page"), "The content is present");

    await visit("/conduct");
    assert.true(
      document.body.classList.contains("static-conduct"),
      "has the body class"
    );
    assert.true(exists(".body-page"), "The content is present");

    await visit("/tos");
    assert.true(
      document.body.classList.contains("static-tos"),
      "has the body class"
    );
    assert.true(exists(".body-page"), "The content is present");

    await visit("/privacy");
    assert.true(
      document.body.classList.contains("static-privacy"),
      "has the body class"
    );
    assert.true(exists(".body-page"), "The content is present");
  });

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

  test("Signup redirect", async function (assert) {
    await visit("/signup");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it redirects to /latest"
    );
  });

  test("Signup redirect with login_required", async function (assert) {
    this.siteSettings.login_required = true;
    await visit("/signup");

    assert.strictEqual(currentRouteName(), "login");
    assert.true(exists(".body-page"), "The content is present");
  });
});
