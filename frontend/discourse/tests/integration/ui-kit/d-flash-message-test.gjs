import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFlashMessage from "discourse/ui-kit/d-flash-message";

module("Integration | ui-kit | DFlashMessage", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the correct class for a success flash", async function (assert) {
    const flash = "Success message";
    const type = "success";

    await render(
      <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
    );

    assert.dom(".alert.alert-success").hasText(flash);
    assert.dom(".alert").hasClass("alert-success");
  });

  test("it renders the correct class for an error flash", async function (assert) {
    const flash = "Error message";
    const type = "error";

    await render(
      <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
    );

    assert.dom(".alert.alert-error").hasText(flash);
    assert.dom(".alert").hasClass("alert-error");
  });

  test("it renders the correct class for a warning flash", async function (assert) {
    const flash = "Warning message";
    const type = "warning";

    await render(
      <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
    );

    assert.dom(".alert.alert-warning").hasText(flash);
    assert.dom(".alert").hasClass("alert-warning");
  });

  test("it renders the correct class for an info flash", async function (assert) {
    const flash = "Info message";
    const type = "info";

    await render(
      <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
    );

    assert.dom(".alert.alert-info").hasText(flash);
    assert.dom(".alert").hasClass("alert-info");
  });

  test("it does not render anything when flash is not provided", async function (assert) {
    await render(<template><DFlashMessage /></template>);

    assert.dom(".alert").doesNotExist();
  });

  test("renders the plain .alert class when no @type is given", async function (assert) {
    await render(<template><DFlashMessage @flash="Plain message" /></template>);

    assert.dom(".alert").hasText("Plain message");
    assert
      .dom(".alert")
      .doesNotHaveClass("alert-success")
      .doesNotHaveClass("alert-error")
      .doesNotHaveClass("alert-warning")
      .doesNotHaveClass("alert-info");
  });

  test("forwards HTML attributes to the alert element", async function (assert) {
    await render(
      <template>
        <DFlashMessage
          @flash="Note"
          @type="info"
          data-test-flash="x"
          id="form-flash"
        />
      </template>
    );

    assert
      .dom(".alert")
      .hasAttribute("data-test-flash", "x")
      .hasAttribute("id", "form-flash");
  });
});
