import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";

acceptance("Plugin Outlet - Deprecated parentView", function (needs) {
  needs.hooks.beforeEach(function () {
    registerTemporaryModule(
      "discourse/templates/connectors/user-profile-primary/hello",
      hbs`<span class='hello-username'>{{this.parentView.parentView.class}}</span>`
    );
  });

  test("Can access parentview", async function (assert) {
    await withSilencedDeprecationsAsync(
      "discourse.plugin-outlet-parent-view",
      async () => {
        await visit("/u/eviltrout");
        assert.strictEqual(
          query(".hello-username").innerText,
          "user-main",
          "it renders a value from parentView.parentView"
        );
      }
    );
  });
});
