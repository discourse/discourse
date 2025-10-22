import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import QueryResult from "../../discourse/components/query-result";

module(
  "Data Explorer Plugin | Integration | Component | query-result",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders query results", async function (assert) {
      const content = {
        colrender: [],
        result_count: 2,
        columns: ["user_name", "like_count"],
        rows: [
          ["user1", 10],
          ["user2", 20],
        ],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom("div.result-info button:nth-child(1) span")
        .hasText(i18n("explorer.download_json"), "renders the JSON button");

      assert
        .dom("div.result-info button:nth-child(2) span")
        .hasText(i18n("explorer.download_csv"), "renders the CSV button");

      assert
        .dom("div.result-info button:nth-child(3) span")
        .hasText(i18n("explorer.show_graph"), "renders the chart button");

      assert.dom("div.result-about").exists("renders a query summary");

      assert.dom("table thead tr th:nth-child(1)").hasText("user_name");
      assert.dom("table thead tr th:nth-child(2)").hasText("like_count");
      assert
        .dom("table tbody tr:nth-child(1) td:nth-child(1)")
        .hasText("user1");
      assert.dom("table tbody tr:nth-child(1) td:nth-child(2)").hasText("10");
      assert
        .dom("table tbody tr:nth-child(2) td:nth-child(1)")
        .hasText("user2");
      assert.dom("table tbody tr:nth-child(2) td:nth-child(2)").hasText("20");
    });

    test("renders badge names in query results", async function (assert) {
      const content = {
        colrender: { 0: "badge" },
        relations: {
          badge: [
            {
              description: "description",
              icon: "user",
              id: 1,
              name: "badge name",
              display_name: "badge display name",
            },
          ],
        },
        result_count: 1,
        columns: ["badge_id"],
        rows: [[1]],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom("table tbody tr:nth-child(1) td:nth-child(1) span")
        .hasText("badge display name");
    });

    test("renders a post in query results", async function (assert) {
      const content = {
        colrender: { 0: "post" },
        relations: {
          post: [
            {
              description: "description",
              id: 1,
              topic_id: 1,
              post_number: 1,
              excerpt: "foo",
              username: "user1",
              avatar_template: "",
            },
          ],
        },
        result_count: 1,
        columns: [""],
        rows: [[1]],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom("table tbody tr:nth-child(1) td:nth-child(1) aside")
        .hasAttribute("data-post", "1");
      assert
        .dom("table tbody tr:nth-child(1) td:nth-child(1) aside")
        .hasAttribute("data-topic", "1");
    });

    test("renders a category_id in query results", async function (assert) {
      const content = {
        colrender: { 0: "category" },
        relations: {
          category: [
            {
              id: 1,
              name: "foo",
              slug: "foo",
              topic_count: 0,
              position: 1,
              description: "a category",
              can_edit: true,
            },
          ],
        },
        result_count: 1,
        columns: [""],
        rows: [[1]],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom(
          "table tbody tr:nth-child(1) td:nth-child(1) .badge-category__name"
        )
        .exists();
    });
  }
);

module(
  "Data Explorer Plugin | Integration | Component | query-result | chart",
  function (hooks) {
    setupRenderingTest(hooks);

    test("navigation between a table and a chart works", async function (assert) {
      const content = {
        colrender: [],
        result_count: 2,
        columns: ["user_name", "like_count"],
        rows: [
          ["user1", 10],
          ["user2", 20],
        ],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom("div.result-info button:nth-child(3) span")
        .hasText(i18n("explorer.show_graph"), "the chart button was rendered");
      assert.dom("table").exists("the table was rendered");

      await click("div.result-info button:nth-child(3)");

      assert
        .dom("div.result-info button:nth-child(3) span")
        .hasText(
          i18n("explorer.show_table"),
          "the chart button was changed to the table button"
        );
      assert.dom("canvas").exists("the chart was rendered");

      await click("div.result-info button:nth-child(3)");
      assert
        .dom("div.result-info button:nth-child(3) span")
        .hasText(
          i18n("explorer.show_graph"),
          "the table button was changed to the chart button"
        );
      assert.dom("table").exists("the table was rendered");
    });

    test("renders a chart button when data has two columns and numbers in the second column", async function (assert) {
      const content = {
        colrender: [],
        result_count: 2,
        columns: ["user_name", "like_count"],
        rows: [
          ["user1", 10],
          ["user2", 20],
        ],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert
        .dom("div.result-info button:nth-child(3) span")
        .hasText(i18n("explorer.show_graph"));
    });

    test("doesn't render a chart button when data contains identifiers in the second column", async function (assert) {
      const content = {
        colrender: { 1: "user" },
        relations: {
          user: [
            { id: 1, username: "user1" },
            { id: 2, username: "user2" },
          ],
        },
        result_count: 2,
        columns: ["topic_id", "user_id"],
        rows: [
          [1, 10],
          [2, 20],
        ],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert.dom("div.result-info button:nth-child(3)").doesNotExist();
    });

    test("doesn't render a chart button when data contains one column", async function (assert) {
      const content = {
        colrender: [],
        result_count: 2,
        columns: ["user_name"],
        rows: [["user1"], ["user2"]],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert.dom("div.result-info button:nth-child(3)").doesNotExist();
    });

    test("doesn't render a chart button when data contains more than two columns", async function (assert) {
      const content = {
        colrender: [],
        result_count: 2,
        columns: ["user_name", "like_count", "post_count"],
        rows: [
          ["user1", 10, 1],
          ["user2", 20, 2],
        ],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert.dom("div.result-info button:nth-child(3)").doesNotExist();
    });

    test("handles no results", async function (assert) {
      const content = {
        colrender: [],
        result_count: 0,
        columns: ["user_name", "like_count", "post_count"],
        rows: [],
      };

      await render(<template><QueryResult @content={{content}} /></template>);

      assert.dom("table tbody tr").doesNotExist("renders no results");
    });
  }
);
