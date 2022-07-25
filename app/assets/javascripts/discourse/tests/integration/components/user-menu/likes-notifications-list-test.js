import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import NotificationFixtures from "discourse/tests/fixtures/notification-fixtures";
import { hbs } from "ember-cli-htmlbars";
import pretender from "discourse/tests/helpers/create-pretender";

function getNotificationsData() {
  return cloneJSON(NotificationFixtures["/notifications"].notifications);
}

module(
  "Integration | Component | user-menu | likes-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    let queryParams = null;
    hooks.beforeEach(() => {
      pretender.get("/notifications", (request) => {
        queryParams = request.queryParams;
        return [
          200,
          { "Content-Type": "application/json" },
          { notifications: getNotificationsData() },
        ];
      });
    });

    hooks.afterEach(() => {
      queryParams = null;
    });

    const template = hbs`<UserMenu::LikesNotificationsList/>`;

    test("requests notifications filtered by the `liked` and `liked_consolidated` types", async function (assert) {
      await render(template);
      assert.strictEqual(
        queryParams.filter_by_types,
        "liked,liked_consolidated"
      );
    });
  }
);
