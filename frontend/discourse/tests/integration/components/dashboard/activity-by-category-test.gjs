import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ActivityByCategory from "discourse/admin/components/dashboard/engagement/activity-by-category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | Dashboard | ActivityByCategory",
  function (hooks) {
    setupRenderingTest(hooks);

    const start = new Date("2026-04-01");
    const end = new Date("2026-04-30");

    const activity = {
      total: 100,
      rows: [
        {
          category_id: 1,
          name: "Support & Help",
          color: "0088CC",
          topics: 412,
          posts: 2184,
          page_views: 28400,
          share: 42,
          share_change: 12,
          share_formatted: "42%",
          share_change_formatted: "+12%",
        },
        {
          category_id: 2,
          name: "General",
          color: "009C00",
          topics: 231,
          posts: 1196,
          page_views: 14200,
          share: 23,
          share_change: 5,
          share_formatted: "23%",
          share_change_formatted: "+5%",
        },
        {
          category_id: 3,
          name: "Bug Reports",
          color: "E45735",
          topics: 61,
          posts: 364,
          page_views: 4600,
          share: 7,
          share_change: -8,
          share_formatted: "7%",
          share_change_formatted: "-8%",
        },
      ],
    };

    test("renders one row per category in the report", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert.dom(".db-activity-table tbody tr").exists({ count: 3 });
    });

    test("renders the section title as a link to the standalone report", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert
        .dom("a.db-section__row-block-title")
        .hasText("Activity by category")
        .hasAttribute("href", /\/admin\/reports\/activity_by_category/);
    });

    test("renders share_change with positive class for gains and negative for losses", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert.dom(".db-delta.--pos").exists({ count: 2 });
      assert.dom(".db-delta.--neg").exists({ count: 1 });
      assert.dom(".db-delta.--neg").hasText("-8%");
    });

    test("formats page views with k suffix when over 1000", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      const cells = document.querySelectorAll(
        ".db-activity-table tbody tr td:nth-child(4)"
      );
      assert.strictEqual(cells[0].textContent.trim(), "28.4k");
      assert.strictEqual(cells[1].textContent.trim(), "14.2k");
      assert.strictEqual(cells[2].textContent.trim(), "4.6k");
    });

    test("renders an empty-state message when there are no rows", async function (assert) {
      const empty = { total: 0, rows: [] };

      await render(
        <template>
          <ActivityByCategory
            @activity={{empty}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert.dom(".db-activity-table").doesNotExist();
      assert.dom(".db-activity__empty").exists();
    });

    test("includes a CategorySelector for filtering", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert.dom(".category-selector").exists();
    });

    test("prefills the selector with the categories shown by default", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert.strictEqual(
        selectKit(".category-selector").header().value(),
        "1,2,3"
      );
    });

    test("renders a category badge for each row instead of a bare swatch", async function (assert) {
      await render(
        <template>
          <ActivityByCategory
            @activity={{activity}}
            @startDate={{start}}
            @endDate={{end}}
          />
        </template>
      );

      assert
        .dom(".db-activity-table__cell-category .badge-category")
        .exists({ count: 3 });
      assert.dom(".db-activity-table__swatch").doesNotExist();
    });
  }
);
