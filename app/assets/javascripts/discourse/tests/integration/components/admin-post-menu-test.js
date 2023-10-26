import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "I18n";

module("Integration | Component | admin-post-menu", function (hooks) {
  setupRenderingTest(hooks);

  test("renders default button", async function (assert) {
    this.currentUser.admin = true;
    this.data = { transformedPost: { id: 1 } };

    await render(hbs`<AdminPostMenu @data={{this.data}} />`);

    assert
      .dom(".moderation-history")
      .hasText(I18n.t("review.moderation_history"));
  });

  test("renders button from API", async function (assert) {
    this.data = { transformedPost: { id: 1 } };

    withPluginApi("1.15.0", (api) => {
      api.addPostAdminMenuButton(() => {
        return {
          translatedLabel: "test",
          className: "test-button",
        };
      });
    });

    await render(hbs`<AdminPostMenu  @data={{this.data}} />`);

    assert.dom(".test-button").hasText("test");
  });
});
