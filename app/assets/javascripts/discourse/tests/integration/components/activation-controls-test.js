import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | activation-controls", function (hooks) {
  setupRenderingTest(hooks);

  test("hides change email button", async function (assert) {
    this.siteSettings.enable_local_logins = false;
    this.siteSettings.email_editable = false;

    await render(hbs`<ActivationControls />`);

    assert.ok(!exists("button.edit-email"));
  });
});
