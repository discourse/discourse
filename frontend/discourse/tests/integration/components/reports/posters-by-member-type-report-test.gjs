import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostersByMemberTypeReport from "discourse/admin/components/reports/posters-by-member-type-report";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Reports | posters-by-member-type-report",
  function (hooks) {
    setupRenderingTest(hooks);

    const model = {
      total: 25,
      start_date: "2026-04-01T00:00:00Z",
      end_date: "2026-04-30T23:59:59Z",
      available_filters: [
        { id: "category_ids", type: "category_list", default: [] },
      ],
      data: [
        {
          type: "new_members",
          kind: "synthetic",
          name: "New members",
          count: 5,
          share: 20,
          share_formatted: "20%",
        },
        {
          type: "returning",
          kind: "synthetic",
          name: "Returning",
          count: 15,
          share: 60,
          share_formatted: "60%",
        },
        {
          type: "staff",
          kind: "synthetic",
          name: "Staff",
          count: 5,
          share: 20,
          share_formatted: "20%",
        },
      ],
    };

    test("renders a row per group plus a totals row", async function (assert) {
      await render(
        <template><PostersByMemberTypeReport @model={{model}} /></template>
      );

      assert.dom(".posters-by-member-type-report__row").exists({ count: 3 });
      assert.dom(".total-row").exists();
      assert.dom(".total-row + tr td:nth-child(2)").hasText("25");
    });

    test("selects the first group by default", async function (assert) {
      await render(
        <template><PostersByMemberTypeReport @model={{model}} /></template>
      );

      assert
        .dom(".posters-by-member-type-report__row:nth-child(1)")
        .hasClass("--selected");
      assert
        .dom(".posters-by-member-type-report__row:nth-child(2)")
        .doesNotHaveClass("--selected");
      assert.dom(".posters-by-member-type-report__members").exists();
    });

    test("clicking a different row moves the selection", async function (assert) {
      await render(
        <template><PostersByMemberTypeReport @model={{model}} /></template>
      );

      await click(".posters-by-member-type-report__row:nth-child(2)");

      assert
        .dom(".posters-by-member-type-report__row:nth-child(1)")
        .doesNotHaveClass("--selected");
      assert
        .dom(".posters-by-member-type-report__row:nth-child(2)")
        .hasClass("--selected");
    });

    test("shows the selected group's name and a way to deselect it", async function (assert) {
      await render(
        <template><PostersByMemberTypeReport @model={{model}} /></template>
      );

      assert
        .dom(".posters-by-member-type-report__members-name")
        .hasText("New members");
      assert
        .dom(".posters-by-member-type-report__members-stats")
        .doesNotExist("doesn't show a stale count before the drill-down loads");

      await click(".posters-by-member-type-report__row:nth-child(2)");

      assert
        .dom(".posters-by-member-type-report__members-name")
        .hasText("Returning");

      await click(".posters-by-member-type-report__members-close");

      assert.dom(".posters-by-member-type-report__members").doesNotExist();
      assert
        .dom(".posters-by-member-type-report__row.--selected")
        .doesNotExist();
    });

    test("shows no members panel when there are no groups", async function (assert) {
      const empty = { ...model, data: [], total: 0 };

      await render(
        <template><PostersByMemberTypeReport @model={{empty}} /></template>
      );

      assert.dom(".posters-by-member-type-report__row").doesNotExist();
      assert.dom(".posters-by-member-type-report__members").doesNotExist();
    });
  }
);
