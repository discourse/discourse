import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ActivationControls from "discourse/components/activation-controls";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | activation-controls", function (hooks) {
  setupRenderingTest(hooks);

  test("hides change email button", async function (assert) {
    this.siteSettings.enable_local_logins = false;
    this.siteSettings.email_editable = false;

    await render(<template><ActivationControls /></template>);

    assert.dom("button.edit-email").doesNotExist();
  });
});
