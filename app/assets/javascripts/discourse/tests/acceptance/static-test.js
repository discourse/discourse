import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Static pages", function () {
  test("/faq", async function (assert) {
    await visit("/faq");
    assert.dom(document.body).hasClass("static-faq", "/faq has the body class");
    assert.dom(".body-page").exists("The content is present");
  });

  test("/guidelines", async function (assert) {
    await visit("/guidelines");
    assert
      .dom(document.body)
      .hasClass("static-guidelines", "has the body class");
    assert.dom(".body-page").exists("The content is present");
  });

  test("/conduct", async function (assert) {
    await visit("/conduct");
    assert.dom(document.body).hasClass("static-conduct", "has the body class");
    assert.dom(".body-page").exists("The content is present");
  });

  test("/tos", async function (assert) {
    await visit("/tos");
    assert.dom(document.body).hasClass("static-tos", "has the body class");
    assert.dom(".body-page").exists("The content is present");
  });

  test("/privacy", async function (assert) {
    await visit("/privacy");
    assert.dom(document.body).hasClass("static-privacy", "has the body class");
    assert.dom(".body-page").exists("The content is present");
  });

  test("/rules", async function (assert) {
    await visit("/rules");
    assert.dom(document.body).hasClass("static-rules", "has the body class");
    assert.dom(".body-page").exists("The content is present");
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
    assert.dom(".body-page").exists("The content is present");
    assert.dom(".sign-up-button").exists();
    assert.dom(".login-button").exists();
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
    assert.dom(".body-page").exists("The content is present");
  });
});
