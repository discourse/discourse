import { currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Auth Complete", function (needs) {
  needs.hooks.beforeEach(function () {
    const node = document.createElement("meta");
    node.dataset.authenticationData = JSON.stringify({
      auth_provider: "test",
      email: "blah@example.com",
    });
    node.id = "data-authentication";
    document.querySelector("head").appendChild(node);
  });

  needs.hooks.afterEach(function () {
    document.getElementById("data-authentication").remove();
  });

  test("when login not required", async function (assert) {
    await visit("/");

    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it stays on the homepage"
    );

    assert
      .dom(".d-modal.create-account")
      .exists("it shows the registration modal");
  });

  test("when login required", async function (assert) {
    this.siteSettings.login_required = true;
    await visit("/");

    assert.strictEqual(
      currentRouteName(),
      "login",
      "it redirects to the login page"
    );

    assert
      .dom(".d-modal.create-account")
      .exists("it shows the registration modal");
  });

  test("Callback added using addBeforeAuthCompleteCallback", async function (assert) {
    withPluginApi("1.11.0", (api) => {
      api.addBeforeAuthCompleteCallback(() => {
        api.container
          .lookup("service:router")
          .transitionTo("discovery.categories");
        return false;
      });
    });

    await visit("/");

    assert.strictEqual(
      currentRouteName(),
      "discovery.categories",
      "The function added via API was run and it transitioned to 'discovery.categories' route"
    );

    assert
      .dom(".d-modal.create-account")
      .doesNotExist("registration modal is not shown");
  });
});
