import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import QueryResult from "../../discourse/components/query-result";

module("Integration | Component | query-result", function (hooks) {
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
      .dom(
        ".result-info .query-result-download-buttons button:nth-child(1) span"
      )
      .hasText(i18n("explorer.download_json"), "renders the JSON button");

    assert
      .dom(
        ".result-info .query-result-download-buttons button:nth-child(2) span"
      )
      .hasText(i18n("explorer.download_csv"), "renders the CSV button");

    assert.dom("div.result-about").exists("renders a query summary");
    assert.dom("canvas").exists("renders the chart above the table");

    assert.dom("table thead tr th:nth-child(1)").hasText("user_name");
    assert.dom("table thead tr th:nth-child(2)").hasText("like_count");
    assert.dom("table tbody tr:nth-child(1) td:nth-child(1)").hasText("user1");
    assert.dom("table tbody tr:nth-child(1) td:nth-child(2)").hasText("10");
    assert.dom("table tbody tr:nth-child(2) td:nth-child(1)").hasText("user2");
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
      .dom("table tbody tr:nth-child(1) td:nth-child(1) .badge-category__name")
      .exists();
  });
});

module("Integration | Component | query-result | chart", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the chart above the table for chartable results", async function (assert) {
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

    assert.dom("canvas").exists("the chart was rendered");
    assert.dom("table").exists("the table was rendered");
    assert
      .dom(".query-results-modes")
      .exists("the chart/table toggle buttons are rendered");
  });

  test("renders a chart when data has two columns and numbers in the second column", async function (assert) {
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

    assert.dom("canvas").exists();
  });

  test("doesn't render a chart when data contains identifiers in the second column", async function (assert) {
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

    assert.dom("canvas").doesNotExist();
  });

  test("doesn't render a chart when data contains one column", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name"],
      rows: [["user1"], ["user2"]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").doesNotExist();
  });

  test("renders a chart when data contains multiple numeric columns", async function (assert) {
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

    assert.dom("canvas").exists();
  });

  test("doesn't render a chart when all non-label columns are relation types", async function (assert) {
    const content = {
      colrender: { 1: "user", 2: "badge" },
      relations: {
        user: [{ id: 1, username: "user1" }],
        badge: [{ id: 1, name: "badge1" }],
      },
      result_count: 1,
      columns: ["topic_id", "user_id", "badge_id"],
      rows: [[1, 1, 1]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").doesNotExist();
  });

  test("renders a chart for date-based data", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["date", "count"],
      rows: [
        ["2024-01-01", 10],
        ["2024-01-02", 20],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").exists("renders a chart canvas");
  });

  test("renders a multi-series chart", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name", "like_count", "post_count"],
      rows: [
        ["user1", 10, 5],
        ["user2", 20, 15],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").exists("renders a chart canvas for multi-series");
  });

  test("doesn't render a chart when there are text columns alongside numeric columns", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["name", "value", "description"],
      rows: [
        ["item1", 10, "some text"],
        ["item2", 20, "other text"],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").doesNotExist();
  });

  test("toggle buttons independently show and hide chart and table", async function (assert) {
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

    assert.dom("canvas").exists("chart is visible by default");
    assert.dom("table").exists("table is visible by default");

    await click(".query-results-modes .btn:first-child");
    assert.dom("canvas").doesNotExist("chart is hidden after toggle");
    assert.dom("table").exists("table remains visible");

    await click(".query-results-modes .btn:last-child");
    assert.dom("canvas").doesNotExist("chart stays hidden");
    assert.dom("table").doesNotExist("table is hidden after toggle");

    await click(".query-results-modes .btn:first-child");
    assert.dom("canvas").exists("chart is visible again");
    assert.dom("table").doesNotExist("table stays hidden");
  });

  test("persists toggle state per query in localStorage", async function (assert) {
    const query = { id: 42 };
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name", "like_count"],
      rows: [
        ["user1", 10],
        ["user2", 20],
      ],
    };

    await render(
      <template><QueryResult @content={{content}} @query={{query}} /></template>
    );

    assert.dom(".query-results-chart").exists("chart is visible by default");
    assert.dom(".query-results-table").exists("table is visible by default");

    await click(".btn-toggle-chart");
    assert
      .dom(".query-results-chart")
      .doesNotExist("chart is hidden after toggle");

    await render(
      <template><QueryResult @content={{content}} @query={{query}} /></template>
    );

    assert
      .dom(".query-results-chart")
      .doesNotExist("chart state is restored from localStorage");
    assert
      .dom(".query-results-table")
      .exists("table state is restored from localStorage");
  });

  test("toggle buttons are not shown for non-chartable data", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name"],
      rows: [["user1"], ["user2"]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom(".query-results-modes").doesNotExist();
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
});
