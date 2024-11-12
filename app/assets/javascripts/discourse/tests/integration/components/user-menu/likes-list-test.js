import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module(
  "Integration | Component | user-menu | likes-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::LikesNotificationsList/>`;
    test("empty state (aka blank page syndrome)", async function (assert) {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });

      await render(template);

      assert.strictEqual(
        query(".empty-state-title").textContent.trim(),
        I18n.t("user.no_likes_title"),
        "empty state title for the likes tab is shown"
      );
      assert
        .dom(".empty-state-body a")
        .hasAttribute(
          "href",
          "/my/preferences/notifications",
          "link to /my/preferences/notification inside empty state body is rendered"
        );
    });
  }
);
