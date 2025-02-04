import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | activation-controls", function (hooks) {
  setupRenderingTest(hooks);

  test("hides change email button", async function (assert) {
    this.siteSettings.enable_local_logins = false;
    this.siteSettings.email_editable = false;

    await render(hbs`<ActivationControls />`);

    assert.dom("button.edit-email").doesNotExist();
  });
});
