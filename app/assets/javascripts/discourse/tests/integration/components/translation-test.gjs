import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Translation from "discourse/components/translation";
import TranslationComponent from "discourse/components/translation-component";
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
          hello: "Bonjour, <user>",
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

  test("component", async function (assert) {
    await render(
      <template>
        <Translation @scope="hello">
          <TranslationComponent @name="user">
            <UserLink @username="pento">pento</UserLink>
          </TranslationComponent>
        </Translation>
      </template>
    );

    assert.dom("span.i18n-container").exists();
    assert.dom("span.i18n-container").hasText("Bonjour, pento");
    assert
      .dom(
        "span.i18n-container span.i18n-component-placeholder a[data-user-card='pento']"
      )
      .exists();

    assert
      .dom(
        "span.i18n-container span.i18n-component-placeholder a[data-user-card='pento']"
      )
      .hasAttribute("aria-label", "Profil de pento");
  });
});
