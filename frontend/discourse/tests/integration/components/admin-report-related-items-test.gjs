import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminReportRelatedItems from "discourse/admin/components/admin-report-related-items";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminReportRelatedItems", function (hooks) {
  setupRenderingTest(hooks);

  test("renders users with profile links", async function (assert) {
    this.set("relatedItems", {
      users: [
        {
          user: {
            id: 1,
            username: "dana_whitfield",
            name: "Dana Whitfield",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/d/3be4f0/{size}.png",
          },
          timestamp: "2026-08-18T08:42:00Z",
        },
      ],
    });

    await render(
      <template>
        <AdminReportRelatedItems
          @relatedItems={{this.relatedItems}}
          @startDate="2026-07-17"
          @endDate="2026-08-18"
          @type="signups"
        />
      </template>
    );

    assert
      .dom(".admin-report-related-items h2")
      .hasText("Users", "labels the user list");
    assert
      .dom(".admin-report-related-items__user-link")
      .hasAttribute("href", "/u/dana_whitfield", "links to the user profile");
    assert
      .dom(".admin-report-related-items__user-link")
      .doesNotHaveAttribute("data-user-card", "does not open a user card");
    assert
      .dom(".admin-report-related-items__name")
      .hasText("Dana Whitfield", "shows the user's name");
  });
});
