import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
  needs.hooks.beforeEach(function () {
    setupAuthData();
  });
  needs.hooks.afterEach(function () {
    document.getElementById("data-authentication").remove();
  });

  test("when skip is disabled (default)", async function (assert) {
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");

    assert.dom("#new-account-username").exists("it shows the fields");

    assert
      .dom(".create-account-associate-link")
      .doesNotExist("it does not show the associate link");
  });

  test("when skip is enabled", async function (assert) {
    this.siteSettings.auth_skip_create_confirm = true;
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");

    assert
      .dom("#new-account-username")
      .doesNotExist("it does not show the fields");
  });
});

acceptance("Create account - with associate link", function (needs) {
  needs.hooks.beforeEach(function () {
    setupAuthData({ associate_url: "/associate/abcde" });
  });
  needs.hooks.afterEach(function () {
    document.getElementById("data-authentication").remove();
  });

  test("displays associate link when allowed", async function (assert) {
    await visit("/");

    assert.dom(".signup-fullpage").exists("it shows the signup page");
    assert.dom("#new-account-username").exists("it shows the fields");
    assert
      .dom(".create-account-associate-link")
      .exists("it shows the associate link");
  });
});
