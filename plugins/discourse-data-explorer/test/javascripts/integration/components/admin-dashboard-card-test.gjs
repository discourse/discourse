import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadChartJS from "discourse/lib/load-chart-js";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DataExplorerAdminDashboardCard from "../../discourse/components/admin-dashboard-card";

function cell(row, col) {
  return `.de-dashboard-card__table tbody tr:nth-child(${row}) td:nth-child(${col})`;
}

async function chartData() {
  const Chart = await loadChartJS();
  return Chart.getChart(find("canvas")).data;
}

module(
  "Integration | Component | DataExplorerAdminDashboardCard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders topics as links", async function (assert) {
      const payload = {
        colrender: { 0: "topic" },
        relations: {
          topic: [
            {
              id: 7,
              title: "Hello world",
              fancy_title: "Hello world",
              slug: "hello-world",
              posts_count: 3,
            },
          ],
        },
        columns: ["topic_id", "views", "replies"],
        rows: [
          [7, 10, 1],
          [8, 20, 2],
        ],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert
        .dom(".de-dashboard-card__table thead th:nth-child(1)")
        .hasText("topic", "strips the id suffix from the header");
      assert
        .dom(`${cell(1, 1)} a`)
        .hasAttribute("href", "/t/hello-world/7", "links to the topic")
        .hasText("Hello world", "renders the title");
      assert
        .dom(cell(2, 1))
        .hasText("8", "renders an unresolved topic id as text");
    });

    test("renders categories and parent categories from the site", async function (assert) {
      const payload = {
        colrender: { 0: "category", 1: "category" },
        columns: ["category_id", "parent_category_id", "topics"],
        rows: [[3, 3, 5]],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert
        .dom(".de-dashboard-card__table thead th:nth-child(2)")
        .hasText("parent category", "strips the id suffix and underscores");
      assert
        .dom(`${cell(1, 1)} .badge-category__name`)
        .hasText("meta", "renders the category badge");
      assert
        .dom(`${cell(1, 2)} .badge-category__name`)
        .hasText("meta", "renders the parent category badge");
    });

    test("renders users, badges, and groups", async function (assert) {
      const payload = {
        colrender: { 0: "user", 1: "badge", 2: "group" },
        relations: {
          user: [
            {
              id: 1,
              username: "eviltrout",
              avatar_template: "/images/avatar.png",
            },
          ],
          badge: [
            {
              id: 1,
              name: "badge name",
              display_name: "badge display name",
              icon: "user",
            },
          ],
        },
        columns: ["user_id", "badge_id", "group_id", "count"],
        rows: [[1, 1, 1, 4]],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert
        .dom(`${cell(1, 1)} a[data-user-card="eviltrout"]`)
        .exists("renders the user link");
      assert
        .dom(`${cell(1, 2)} .badge-display-name`)
        .hasText("badge display name", "renders the badge");
      assert
        .dom(`${cell(1, 3)} a`)
        .hasText("admins", "resolves the group from the site");
    });

    test("renders post ids as plain text", async function (assert) {
      const payload = {
        colrender: { 0: "post" },
        relations: {
          post: [
            {
              id: 1,
              topic_id: 1,
              post_number: 1,
              excerpt: "foo",
              username: "user1",
              avatar_template: "",
            },
          ],
        },
        columns: ["post_id", "likes", "flags"],
        rows: [[1, 2, 0]],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert.dom(cell(1, 1)).hasText("1", "keeps the raw id");
      assert
        .dom(`${cell(1, 1)} aside`)
        .doesNotExist("does not render the post excerpt");
    });

    test("marks relations hidden from the current user", async function (assert) {
      const payload = {
        colrender: { 0: "topic" },
        relations: { topic: [] },
        hidden_relations: { topic: [42] },
        columns: ["topic_id", "views", "replies"],
        rows: [[42, 1, 0]],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert
        .dom(`${cell(1, 1)} .query-result-hidden`)
        .hasText("42", "keeps the id with the hidden marker");
    });

    test("labels chart entries with the resolved relation", async function (assert) {
      const payload = {
        colrender: { 0: "category" },
        columns: ["category_id", "count"],
        rows: [
          [3, 10],
          [999, 20],
        ],
      };

      await render(
        <template>
          <DataExplorerAdminDashboardCard @payload={{payload}} />
        </template>
      );

      assert.dom("canvas").exists("renders a chart for two-column results");
      assert.deepEqual(
        (await chartData()).labels,
        ["meta", 999],
        "uses the category name and falls back to the raw id"
      );
    });
  }
);
