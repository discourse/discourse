import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LikesNotificationsList from "discourse/components/user-menu/likes-notifications-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | user-menu | likes-notifications-list",
  function (hooks) {
    setupRenderingTest(hooks);

    test("empty state (aka blank page syndrome)", async function (assert) {
      pretender.get("/notifications", () => {
        return response({ notifications: [] });
      });

      await render(<template><LikesNotificationsList /></template>);

      assert
        .dom(".empty-state__title")
        .hasText(
          i18n("user.no_likes_title"),
          "empty state title for the likes tab is shown"
        );
      assert
        .dom(".empty-state__body a")
        .hasAttribute(
          "href",
          "/my/preferences/notifications",
          "link to /my/preferences/notification inside empty state body is rendered"
        );
    });
  }
);
