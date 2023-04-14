import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

function setupAuthData(data) {
  data = {
    auth_provider: "test",
    email: "blah@example.com",
    can_edit_username: true,
    can_edit_name: true,
    ...data,
  };

  const node = document.createElement("meta");
  node.dataset.authenticationData = JSON.stringify(data);
  node.id = "data-authentication";
  document.querySelector("head").appendChild(node);
}

acceptance("Create Account - external auth", function (needs) {
  needs.hooks.beforeEach(() => {
    setupAuthData();
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

    assert.notOk(
      exists(".create-account-associate-link"),
      "it does not show the associate link"
    );
  });

  test("when skip is enabled", async function (assert) {
    this.siteSettings.auth_skip_create_confirm = true;
    await visit("/");

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );

    assert.notOk(
      exists("#new-account-username"),
      "it does not show the fields"
    );
  });
});

acceptance("Create account - with associate link", function (needs) {
  needs.hooks.beforeEach(() => {
    setupAuthData({ associate_url: "/associate/abcde" });
  });
  needs.hooks.afterEach(() => {
    document
      .querySelector("head")
      .removeChild(document.getElementById("data-authentication"));
  });

  test("displays associate link when allowed", async function (assert) {
    await visit("/");

    assert.ok(
      exists("#discourse-modal div.create-account-body"),
      "it shows the registration modal"
    );
    assert.ok(exists("#new-account-username"), "it shows the fields");
    assert.ok(
      exists(".create-account-associate-link"),
      "it shows the associate link"
    );
  });
});
