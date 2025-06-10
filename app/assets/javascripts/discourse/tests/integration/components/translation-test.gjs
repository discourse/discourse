import { array } from "@ember/helper";
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
        <Translation @scope="hello" @placeholders={{array "username"}}>
          <:placeholders as |placeholder|>
            <placeholder @name="username">
              <UserLink @username="pento">pento</UserLink>
            </placeholder>
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
});
