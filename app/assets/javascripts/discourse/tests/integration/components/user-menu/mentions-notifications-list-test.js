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
  "Integration | Component | user-menu | mentions-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    let notificationsData = getNotificationsData();
    let queryParams = null;
    hooks.beforeEach(() => {
      pretender.get("/notifications", (request) => {
        queryParams = request.queryParams;
        return [
          200,
          { "Content-Type": "application/json" },
          { notifications: notificationsData },
        ];
      });
    });

    hooks.afterEach(() => {
      notificationsData = getNotificationsData();
      queryParams = null;
    });

    const template = hbs`<UserMenu::MentionsNotificationsList/>`;

    test("requests notifications filtered by the `mentioned` type", async function (assert) {
      await render(template);
      assert.strictEqual(queryParams.filter_by_types, "mentioned");
    });
  }
);
