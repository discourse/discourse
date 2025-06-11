import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Translation from "discourse/components/translation";
import UserLink from "discourse/components/user-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

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
        <Translation @scope="hello">
          <:placeholders as |Placeholder|>
            <Placeholder @name="username">
              <UserLink @username="pento">pento</UserLink>
            </Placeholder>
          </:placeholders>
        </Translation>
      </template>
    );

    assert.dom().hasText("Bonjour, pento");
    assert.dom("a[data-user-card='pento']").exists();
    assert
      .dom("a[data-user-card='pento']")
      .hasAttribute("aria-label", "Profil de pento");
  });

  test("renders simple translation without placeholders", async function (assert) {
    await render(<template><Translation @scope="simple_text" /></template>);

    assert.dom().hasText("Simple text without placeholders");
  });

  test("renders translation with string options only", async function (assert) {
    await render(
      <template>
        <Translation
          @scope="with_options"
          @options={{hash name="John" site="Discourse"}}
        />
      </template>
    );

    assert.dom().hasText("Hello John, welcome to Discourse!");
  });

  test("renders translation with both string options and component placeholders", async function (assert) {
    await render(
      <template>
        <Translation @scope="mixed_placeholders" @options={{hash count=5}}>
          <:placeholders as |Placeholder|>
            <Placeholder @name="username">
              <UserLink @username="alice">alice</UserLink>
            </Placeholder>
          </:placeholders>
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
          @scope="multiple_placeholders"
          @options={{hash time="2:30 PM"}}
        >
          <:placeholders as |Placeholder|>
            <Placeholder @name="user">
              <UserLink @username="bob">bob</UserLink>
            </Placeholder>
            <Placeholder @name="topic">
              <strong>Important Topic</strong>
            </Placeholder>
          </:placeholders>
        </Translation>
      </template>
    );

    assert.dom().hasText("User bob commented on Important Topic at 2:30 PM");
    assert.dom("a[data-user-card='bob']").exists();
    assert.dom("strong").hasText("Important Topic");
  });

  test("handles missing translation key gracefully", async function (assert) {
    // Add a fallback translation for missing keys
    await render(<template><Translation @scope="nonexistent_key" /></template>);

    // When a translation key is missing, i18n returns the key itself
    assert.dom().hasText("[fr.nonexistent_key]");
  });

  test("handles placeholder not provided in template", async function (assert) {
    // Translation has %{username} placeholder but no placeholder component is provided
    await render(
      <template>
        <Translation @scope="hello">
          <:placeholders>
          </:placeholders>
        </Translation>
      </template>
    );

    // Should render the placeholder string since no component was provided
    assert.dom().includesText("Bonjour, [missing %{username} placeholder]");
  });
});
