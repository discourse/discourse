import { currentRouteName, visit } from "@ember/test-helpers";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Login redirect - anonymous", function () {
  test("redirects login to default homepage", async function (assert) {
    await visit("/login");
    assert.strictEqual(
      currentRouteName(),
      "discovery.latest",
      "it works when latest is the homepage"
    );
  });
});

acceptance("Login redirect - categories default", function (needs) {
  needs.settings({
    top_menu: "categories|latest|top|hot",
  });

  test("when site setting is categories", async function (assert) {
    await visit("/login");
    assert.strictEqual(
      currentRouteName(),
      "discovery.categories",
      "it works when categories is the homepage"
    );
  });
});
