import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DTogglePasswordMask from "discourse/ui-kit/d-toggle-password-mask";
import { i18n } from "discourse-i18n";

const noop = () => {};

module("Integration | ui-kit | DTogglePasswordMask", function (hooks) {
  setupRenderingTest(hooks);

  test("offers to show a masked password", async function (assert) {
    await render(
      <template>
        <DTogglePasswordMask
          @maskPassword={{true}}
          @togglePasswordMask={{noop}}
        />
      </template>
    );

    assert
      .dom(".toggle-password-mask")
      .hasAttribute(
        "title",
        i18n("login.show_password_title"),
        "the title offers to show the password"
      );
    assert
      .dom(".toggle-password-mask .d-icon-far-eye")
      .exists("an open eye is shown");
  });

  test("offers to hide a visible password", async function (assert) {
    await render(
      <template>
        <DTogglePasswordMask
          @maskPassword={{false}}
          @togglePasswordMask={{noop}}
        />
      </template>
    );

    assert
      .dom(".toggle-password-mask")
      .hasAttribute(
        "title",
        i18n("login.hide_password_title"),
        "the title offers to hide the password"
      );
    assert
      .dom(".toggle-password-mask .d-icon-far-eye-slash")
      .exists("a crossed eye is shown");
  });

  test("calls @togglePasswordMask on click", async function (assert) {
    let toggled = 0;
    const toggle = () => toggled++;

    await render(
      <template>
        <DTogglePasswordMask
          @maskPassword={{true}}
          @togglePasswordMask={{toggle}}
        />
      </template>
    );
    await click(".toggle-password-mask");

    assert.strictEqual(toggled, 1, "@togglePasswordMask is called once");
  });
});
