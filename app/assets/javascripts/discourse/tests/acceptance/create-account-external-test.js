import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Create Account - external auth", function (needs) {
  needs.hooks.beforeEach(() => {
    const node = document.createElement("meta");
    node.dataset.authenticationData = JSON.stringify({
      auth_provider: "test",
      email: "blah@example.com",
      can_edit_username: true,
      can_edit_name: true,
    });
    node.id = "data-authentication";
    document.querySelector("head").appendChild(node);
  });
  needs.hooks.afterEach(() => {
    document
      .querySelector("head")
      .removeChild(document.getElementById("data-authentication"));
  });

  test("when skip is disabled (default)", async function (assert) {
    await visit("/");

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );

    assert.ok(exists("#new-account-username"), "it shows the fields");
  });

  test("when skip is enabled", async function (assert) {
    this.siteSettings.auth_skip_create_confirm = true;
    await visit("/");

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );

    assert.not(exists("#new-account-username"), "it does not show the fields");
  });
});
