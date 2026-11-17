import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFlashMessage from "discourse/ui-kit/d-flash-message";

module("Integration | ui-kit | DFlashMessage", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    disableClearA11yAnnouncementsInTests();
  });

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

  test("an error is announced assertively", async function (assert) {
    const flash = "Error message";
    const type = "error";

    await render(
      <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
    );

    const a11y = getOwner(this).lookup("service:a11y");
    assert.strictEqual(a11y.assertiveMessage, flash);
    assert.notStrictEqual(a11y.politeMessage, flash);
    assert.dom(".alert").doesNotHaveAttribute("role");
  });

  test("success, warning, info and untyped messages are announced politely", async function (assert) {
    const flash = "A message";
    const types = ["success", "warning", "info", undefined];
    const a11y = getOwner(this).lookup("service:a11y");

    for (const type of types) {
      a11y.announce("", "polite");
      await render(
        <template><DFlashMessage @flash={{flash}} @type={{type}} /></template>
      );

      assert.strictEqual(
        a11y.politeMessage,
        flash,
        `${type ?? "untyped"} is announced politely`
      );
    }
  });

  test("@announce overrides how a message is announced", async function (assert) {
    const flash = "A message";
    const a11y = getOwner(this).lookup("service:a11y");

    await render(
      <template>
        <DFlashMessage @announce="assertive" @flash={{flash}} @type="warning" />
      </template>
    );
    assert.strictEqual(a11y.assertiveMessage, flash);

    a11y.announce("", "assertive");
    a11y.announce("", "polite");
    await render(
      <template>
        <DFlashMessage @announce={{false}} @flash={{flash}} @type="error" />
      </template>
    );
    assert.notStrictEqual(a11y.assertiveMessage, flash, "stays silent");
    assert.notStrictEqual(a11y.politeMessage, flash, "stays silent");
  });

  test("a message that changes while shown is announced again", async function (assert) {
    const state = trackedObject({ flash: "First error" });
    const a11y = getOwner(this).lookup("service:a11y");

    await render(
      <template>
        <DFlashMessage @flash={{state.flash}} @type="error" />
      </template>
    );
    assert.strictEqual(a11y.assertiveMessage, "First error");

    state.flash = "Second error";
    await settled();
    assert.strictEqual(a11y.assertiveMessage, "Second error");
  });

  test("it does not render anything when flash is not provided", async function (assert) {
    await render(<template><DFlashMessage /></template>);

    assert.dom(".alert").doesNotExist();
  });
});
