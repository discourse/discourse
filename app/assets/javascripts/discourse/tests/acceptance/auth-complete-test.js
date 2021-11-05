import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Auth Complete", function (needs) {
  needs.hooks.beforeEach(() => {
    const node = document.createElement("meta");
    node.dataset.authenticationData = JSON.stringify({
      auth_provider: "test",
      email: "blah@example.com",
    });
    node.id = "data-authentication";
    document.querySelector("head").appendChild(node);
  });

  needs.hooks.afterEach(() => {
    document
      .querySelector("head")
      .removeChild(document.getElementById("data-authentication"));
  });

  test("when login not required", async function (assert) {
    await visit("/");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it stays on the homepage"
    );

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );
  });

  test("when login required", async function (assert) {
    this.siteSettings.login_required = true;
    await visit("/");

    assert.strictEqual(
      currentRouteName(),
      "login",
      "it redirects to the login page"
    );

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );
  });
});
