import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CodeLoginNameField from "discourse/components/code-login-form/name-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const noop = () => {};

module("Integration | Component | CodeLoginNameField", function (hooks) {
  setupRenderingTest(hooks);

  test("hides instructions by default", async function (assert) {
    this.siteSettings.show_signup_form_full_name_instructions = false;

    await render(<template><CodeLoginNameField @onInput={{noop}} /></template>);

    assert.dom("#code-login-name").exists();
    assert.dom("#code-login-name-instructions").doesNotExist();
  });

  test("shows required instructions when the name is required", async function (assert) {
    this.siteSettings.show_signup_form_full_name_instructions = true;

    await render(
      <template>
        <CodeLoginNameField @onInput={{noop}} @required={{true}} />
      </template>
    );

    assert
      .dom("#code-login-name-instructions")
      .hasText(i18n("user.name.instructions_required"));
  });

  test("shows optional instructions when the name is optional", async function (assert) {
    this.siteSettings.show_signup_form_full_name_instructions = true;

    await render(<template><CodeLoginNameField @onInput={{noop}} /></template>);

    assert
      .dom("#code-login-name-instructions")
      .hasText(i18n("user.name.instructions"));
  });

  test("replaces instructions with the error", async function (assert) {
    this.siteSettings.show_signup_form_full_name_instructions = true;

    await render(
      <template>
        <CodeLoginNameField @error="Name is required" @onInput={{noop}} />
      </template>
    );

    assert.dom("#code-login-name-instructions").doesNotExist();
    assert.dom("#code-login-name-error").hasText("Name is required");
  });
});
