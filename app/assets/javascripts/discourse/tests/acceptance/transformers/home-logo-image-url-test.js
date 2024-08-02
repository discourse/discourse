import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("home-logo-image-url transformer", function () {
  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "home-logo-image-url",
        ({ value }) => "/transformed" + value
      );
    });

    await visit("/");

    assert
      .dom("#site-logo")
      .hasAttribute(
        "src",
        "/transformed/assets/logo.png",
        "it transforms the logo url"
      );
  });
});
