import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FlashMessage from "discourse/components/flash-message";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | flash-message", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the correct class for a success flash", async function (assert) {
    const flash = "Success message";
    const type = "success";

    await render(<template>
      <FlashMessage @flash={{flash}} @type={{type}} />
    </template>);

    assert.dom(".alert.alert-success").hasText(flash);
    assert.dom(".alert").hasClass("alert-success");
  });

  test("it renders the correct class for an error flash", async function (assert) {
    const flash = "Error message";
    const type = "error";

    await render(<template>
      <FlashMessage @flash={{flash}} @type={{type}} />
    </template>);

    assert.dom(".alert.alert-error").hasText(flash);
    assert.dom(".alert").hasClass("alert-error");
  });

  test("it renders the correct class for a warning flash", async function (assert) {
    const flash = "Warning message";
    const type = "warning";

    await render(<template>
      <FlashMessage @flash={{flash}} @type={{type}} />
    </template>);

    assert.dom(".alert.alert-warning").hasText(flash);
    assert.dom(".alert").hasClass("alert-warning");
  });

  test("it renders the correct class for an info flash", async function (assert) {
    const flash = "Info message";
    const type = "info";

    await render(<template>
      <FlashMessage @flash={{flash}} @type={{type}} />
    </template>);

    assert.dom(".alert.alert-info").hasText(flash);
    assert.dom(".alert").hasClass("alert-info");
  });

  test("it does not render anything when flash is not provided", async function (assert) {
    await render(<template><FlashMessage /></template>);

    assert.dom(".alert").doesNotExist();
  });
});
