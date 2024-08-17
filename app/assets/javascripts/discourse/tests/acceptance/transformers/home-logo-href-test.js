import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("home-logo-href transformer", function () {
  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "home-logo-href",
        ({ value }) => value + "transformed"
      );
    });

    await visit("/");

    assert
      .dom(".title > a")
      .hasAttribute("href", "/transformed", "it transforms the logo link href");
  });
});
