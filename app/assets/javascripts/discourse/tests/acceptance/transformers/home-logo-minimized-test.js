import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("home-logo-minimized transformer", function () {
  test("can force minimize the logo", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer("home-logo-minimized", () => true);
    });

    await visit("/");
    assert.dom("#site-logo").hasClass("logo-small");
  });

  test("can force un-minimize the logo", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer("home-logo-minimized", () => false);
    });

    await visit("/");
    assert.dom("#site-logo").hasClass("logo-big");
  });
});
