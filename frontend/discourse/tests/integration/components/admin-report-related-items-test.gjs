import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminReportRelatedItems from "discourse/admin/components/admin-report-related-items";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | AdminReportRelatedItems", function (hooks) {
  setupRenderingTest(hooks);

  test("renders users with profile links", async function (assert) {
    const clock = fakeTime("2026-08-20T12:00:00", null, true);

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
    this.set("relatedItemsTotals", { users: 3 });

    try {
      await render(
        <template>
          <AdminReportRelatedItems
            @relatedItems={{this.relatedItems}}
            @relatedItemsTotals={{this.relatedItemsTotals}}
            @startDate="2026-07-17"
            @endDate="2026-08-18"
            @type="new_contributors"
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
      assert
        .dom("thead .admin-report-related-items__timestamp-cell")
        .hasText("First post created at", "labels the first-post timestamp");
      assert
        .dom(".admin-report-related-items__timestamp-cell time")
        .hasText("2 days ago", "shows a relative timestamp with ago");
      assert
        .dom(".admin-report-related-items__limit")
        .hasText(
          "Showing the newest 1 of 3.",
          "discloses that the list is limited"
        );
    } finally {
      clock.restore();
    }
  });

  test("preserves report dates in positive UTC offsets", async function (assert) {
    this.set("relatedItems", {
      users: [
        {
          user: {
            id: 1,
            username: "dana_whitfield",
            avatar_template:
              "/letter_avatar_proxy/v4/letter/d/3be4f0/{size}.png",
          },
          timestamp: "2026-08-18T08:42:00Z",
        },
      ],
    });
    this.set("startDate", moment.parseZone("2026-07-26T00:00:00+08:00"));
    this.set("endDate", moment.parseZone("2026-08-27T00:00:00+08:00"));

    await render(
      <template>
        <AdminReportRelatedItems
          @relatedItems={{this.relatedItems}}
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
          @type="signups"
        />
      </template>
    );

    assert
      .dom(".admin-report-related-items__description")
      .hasText(
        "New accounts created between Jul 26, 2026 and Aug 27, 2026, newest first.",
        "keeps the selected calendar dates"
      );
  });
});
