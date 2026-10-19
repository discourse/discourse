import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import Patreon from "discourse/plugins/discourse-patreon/discourse/connectors/admin-user-details/patreon";

module(
  "Integration | Component | Patreon admin user details",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows the decline date and looks up the email", async function (assert) {
      pretender.get("/u/patron/patreon_email.json", () =>
        response({ email: "patron@example.com" })
      );
      const model = {
        username_lower: "patron",
        patreon_id: "123",
        patreon_email_exists: true,
        patreon_declined_since: "2026-01-02T10:00:00Z",
      };

      await render(<template><Patreon @model={{model}} /></template>);

      assert
        .dom(".patreon .display-row:nth-child(4) .value")
        .hasAnyText("shows when the pledge was declined");

      await click(".patreon .btn-default");

      assert
        .dom(".patreon")
        .includesText("patron@example.com", "shows the looked-up email");
      assert
        .dom(".patreon a[target='_blank']")
        .hasAttribute(
          "href",
          "https://patreon.com/members?query=patron@example.com"
        );
    });
  }
);
