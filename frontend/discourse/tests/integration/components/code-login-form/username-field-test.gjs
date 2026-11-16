import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CodeLoginUsernameField from "discourse/components/code-login-form/username-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const noop = () => {};

module("Integration | Component | CodeLoginUsernameField", function (hooks) {
  setupRenderingTest(hooks);

  test("hides instructions by default", async function (assert) {
    this.siteSettings.show_signup_form_username_instructions = false;

    await render(
      <template><CodeLoginUsernameField @onInput={{noop}} /></template>
    );

    assert.dom("#code-login-username").exists();
    assert.dom("#code-login-username-instructions").doesNotExist();
  });

  test("shows instructions when the site setting is enabled", async function (assert) {
    this.siteSettings.show_signup_form_username_instructions = true;

    await render(
      <template><CodeLoginUsernameField @onInput={{noop}} /></template>
    );

    assert
      .dom("#code-login-username-instructions")
      .hasText(i18n("user.username.instructions"));
    assert
      .dom("#code-login-username")
      .hasAttribute(
        "aria-describedby",
        "code-login-username-instructions code-login-username-error"
      );
  });

  test("replaces instructions with the error", async function (assert) {
    this.siteSettings.show_signup_form_username_instructions = true;

    await render(
      <template>
        <CodeLoginUsernameField @error="Username taken" @onInput={{noop}} />
      </template>
    );

    assert.dom("#code-login-username-instructions").doesNotExist();
    assert.dom("#code-login-username-error").hasText("Username taken");
    assert.dom("#code-login-username").hasAttribute("aria-invalid", "true");
  });

  test("passes input and attributes through", async function (assert) {
    let typed;
    const onInput = (event) => (typed = event.target.value);

    await render(
      <template>
        <CodeLoginUsernameField
          @autocomplete="off"
          @disabled={{false}}
          @onInput={{onInput}}
          @value="jane"
        />
      </template>
    );

    assert
      .dom("#code-login-username")
      .hasValue("jane")
      .hasAttribute("autocomplete", "off");

    await fillIn("#code-login-username", "joe");

    assert.strictEqual(typed, "joe");
  });
});
