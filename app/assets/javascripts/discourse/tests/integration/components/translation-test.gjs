import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import {
  render,
  resetOnerror,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import Translation from "discourse/components/translation";
import UserLink from "discourse/components/user-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n, { I18nMissingInterpolationArgument } from "discourse-i18n";

module("Integration | Component | Translation", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this._locale = I18n.locale;
    this._translations = I18n.translations;

    I18n.locale = "fr";

    I18n.translations = {
      fr: {
        js: {
          hello: "Bonjour, %{username}",
          simple_text: "Simple text without placeholders",
          with_options: "Hello %{name}, welcome to %{site}!",
          multiple_placeholders:
            "User %{user} commented on %{topic} at %{time}",
          mixed_placeholders:
            "Welcome %{username}! You have %{count} messages.",
          repeated_placeholders: "Welcome %{username}! Hello %{username}!",
          user: {
            profile_possessive: "Profil de %{username}",
          },
        },
      },
    };
  });

  hooks.afterEach(function () {
    I18n.locale = this._locale;
    I18n.translations = this._translations;
  });

  test("renders translation with component placeholder", async function (assert) {
    await render(
      <template>
        <Translation @key="hello" as |Placeholder|>
          <Placeholder @name="username">
            <UserLink @username="pento">pento</UserLink>
          </Placeholder>
        </Translation>
      </template>
    );

    assert.dom().hasText("Bonjour, pento");
    assert.dom("a[data-user-card='pento']").exists();
    assert
      .dom("a[data-user-card='pento']")
      .hasAttribute("aria-label", "Profil de pento");
  });

  test("renders translation with repeated component placeholder", async function (assert) {
    await render(
      <template>
        <Translation @key="repeated_placeholders" as |Placeholder|>
          <Placeholder @name="username">
            <UserLink @username="pento">pento</UserLink>
          </Placeholder>
        </Translation>
      </template>
    );

    assert.dom().hasText("Welcome pento ! Hello pento !");
    assert.dom("a[data-user-card='pento']").exists({ count: 2 });
  });

  test("throws an error on simple translation without placeholders", async function (assert) {
    let errors = 0;

    setupOnerror((error) => {
      assert.strictEqual(
        error.message,
        "The <Translation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      );

      errors++;
    });

    await render(<template><Translation @key="simple_text" /></template>);

    assert.strictEqual(errors, 1);
    resetOnerror();
  });

  test("renders translation with string options only", async function (assert) {
    let errors = 0;

    setupOnerror((error) => {
      assert.strictEqual(
        error.message,
        "The <Translation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      );

      errors++;
    });

    await render(
      <template>
        <Translation
          @key="with_options"
          @options={{hash name="John" site="Discourse"}}
        />
      </template>
    );

    assert.strictEqual(errors, 1);
    resetOnerror();
  });

  test("renders translation with both string options and component placeholders", async function (assert) {
    await render(
      <template>
        <Translation
          @key="mixed_placeholders"
          @options={{hash count=5}}
          as |Placeholder|
        >
          <Placeholder @name="username">
            <UserLink @username="alice">alice</UserLink>
          </Placeholder>
        </Translation>
      </template>
    );

    assert.dom().hasText("Welcome alice ! You have 5 messages.");
    assert.dom("a[data-user-card='alice']").exists();
  });

  test("renders translation with multiple component placeholders", async function (assert) {
    await render(
      <template>
        <Translation
          @key="multiple_placeholders"
          @options={{hash time="2:30 PM"}}
          as |Placeholder|
        >
          <Placeholder @name="user">
            <UserLink @username="bob">bob</UserLink>
          </Placeholder>
          <Placeholder @name="topic">
            <strong>Important Topic</strong>
          </Placeholder>
        </Translation>
      </template>
    );

    assert.dom().hasText("User bob commented on Important Topic at 2:30 PM");
    assert.dom("a[data-user-card='bob']").exists();
    assert.dom("strong").hasText("Important Topic");
  });

  test("handles missing translation key gracefully", async function (assert) {
    await render(<template><Translation @key="nonexistent_key" /></template>);

    // When a translation key is missing, i18n returns the key itself
    assert.dom().hasText("[fr.nonexistent_key]");
  });

  test("handles placeholder not provided in template", async function (assert) {
    let errors = 0;
    setupOnerror((error) => {
      assert.true(error instanceof I18nMissingInterpolationArgument);
      assert.strictEqual(
        error.message,
        "Translation error for key 'hello': [missing %{username} placeholder]"
      );

      errors++;
    });

    // Translation has %{username} placeholder but no placeholder component is provided
    await render(<template><Translation @key="hello" /></template>);

    assert.strictEqual(errors, 1);
    resetOnerror();

    // Should render the placeholder string since no component was provided
    assert.dom().includesText("Bonjour, [missing %{username} placeholder]");
  });

  test("correctly re-renders when args change", async function (assert) {
    const state = new (class {
      @tracked key = "hello";
      @tracked options = {};
    })();

    await render(
      <template>
        <Translation
          @key={{state.key}}
          @options={{state.options}}
          as |Placeholder|
        >
          <Placeholder @name="username">
            <UserLink @username="pento">pento</UserLink>
          </Placeholder>
        </Translation>
      </template>
    );

    assert.dom().hasText("Bonjour, pento");

    let errors = 0;

    setupOnerror((error) => {
      assert.strictEqual(
        error.message,
        "The <Translation> component shouldn't be used for translations that don't insert components. Use `i18n()` instead."
      );
      errors++;
    });

    state.key = "simple_text";
    await settled();

    assert.dom().hasText("Simple text without placeholders");

    assert.strictEqual(errors, 1);
    resetOnerror();
  });
});
