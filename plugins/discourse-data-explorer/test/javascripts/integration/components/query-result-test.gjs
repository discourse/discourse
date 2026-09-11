import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadChartJS from "discourse/lib/load-chart-js";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import QueryResult from "discourse/plugins/discourse-data-explorer/discourse/components/query-result";

function cell(row, col) {
  return `table tbody tr:nth-child(${row}) td:nth-child(${col})`;
}

async function chartData() {
  const Chart = await loadChartJS();
  return Chart.getChart(find("canvas")).data;
}

module("Integration | Component | QueryResult", function (hooks) {
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

    await click(".result-actions .query-result-download-buttons");

    assert
      .dom(".query-result-export__results-json")
      .hasText(
        i18n("explorer.export_as.results_json"),
        "renders the Results (JSON) item"
      );

    assert
      .dom(".query-result-export__results-csv")
      .hasText(
        i18n("explorer.export_as.results_csv"),
        "renders the Results (CSV) item"
      );

    assert.dom("div.result-about").exists("renders a query summary");
    assert.dom("canvas").exists("renders the chart by default");

    await click(".query-results-modes input[value='table']");

    assert.dom("table thead tr th:nth-child(1)").hasText("user_name");
    assert.dom("table thead tr th:nth-child(2)").hasText("like_count");
    assert.dom(cell(1, 1)).hasText("user1");
    assert.dom(cell(1, 2)).hasText("10");
    assert.dom(cell(2, 1)).hasText("user2");
    assert.dom(cell(2, 2)).hasText("20");
  });

  test("renders JSON columns as escaped text with a viewer action", async function (assert) {
    const content = {
      colrender: { 1: "json" },
      result_count: 1,
      columns: ["name", "response_format"],
      rows: [["classifier", '[{"key":"<img src=x onerror=alert(1)>"}]']],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(`${cell(1, 2)} .result-json-value`)
      .hasText(
        '[{"key":"<img src=x onerror=alert(1)>"}]',
        "renders JSON as readable text without HTML entities"
      );
    assert
      .dom(`${cell(1, 2)} img`)
      .doesNotExist("does not render HTML from JSON values");
    assert
      .dom(`${cell(1, 2)} .result-json-button`)
      .exists("renders a JSON viewer action");
  });

  test("renders plain text without double-escaping HTML entities", async function (assert) {
    const content = {
      colrender: [],
      result_count: 1,
      columns: ["value"],
      rows: [['{"key":"<script>alert(1)</script>"}']],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(cell(1, 1))
      .hasText('{"key":"<script>alert(1)</script>"}', "renders readable text");
    assert
      .dom(`${cell(1, 1)} script`)
      .doesNotExist("does not render HTML from text values");
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

    assert.dom(`${cell(1, 1)} span`).hasText("badge display name");
    assert.dom(`${cell(1, 1)} svg`).exists("renders the icon as an svg");
    assert
      .dom(`${cell(1, 1)} img`)
      .doesNotExist("does not treat the icon name as an image url");
  });

  test("renders chart labels when a badge cannot be resolved", async function (assert) {
    const content = {
      colrender: { 0: "badge" },
      relations: {
        badge: [
          { id: 1, name: "badge name", display_name: "badge display name" },
        ],
      },
      result_count: 2,
      columns: ["user_badge_id", "count"],
      rows: [
        [1, 10],
        [999, 20],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.deepEqual(
      (await chartData()).labels,
      ["badge name", "999"],
      "falls back to the raw id for an unresolved badge"
    );
  });

  test("renders the raw cell when a relation cannot be resolved", async function (assert) {
    const content = {
      colrender: { 0: "topic", 1: "user", 2: "badge", 3: "url" },
      relations: { topic: [], user: [], badge: [] },
      result_count: 1,
      columns: ["topic_id", "user_id", "user_badge_id", "some_url"],
      rows: [[42, "abc", 999, 1]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(cell(1, 1))
      .hasText("42", "renders the unresolved topic id as text");
    assert
      .dom(`${cell(1, 1)} a`)
      .doesNotExist("does not link to a topic that cannot be resolved");
    assert.dom(cell(1, 2)).hasText("abc", "renders a non-numeric id verbatim");
    assert
      .dom(cell(1, 3))
      .hasText("999", "renders the unresolved badge id as text");
    assert
      .dom(`${cell(1, 4)} a`)
      .hasAttribute("href", "1", "renders a numeric url cell as a link");
  });

  test("marks relations hidden from the current user", async function (assert) {
    const content = {
      colrender: { 0: "topic" },
      relations: { topic: [] },
      hidden_relations: { topic: [42] },
      result_count: 2,
      columns: ["topic_id"],
      rows: [[42], [43]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(`${cell(1, 1)} .query-result-hidden`)
      .hasText("42", "keeps the id");
    assert.dom(`${cell(2, 1)} svg`).doesNotExist("unresolved ids stay plain");
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

    assert.dom(`${cell(1, 1)} aside`).hasAttribute("data-post", "1");
    assert.dom(`${cell(1, 1)} aside`).hasAttribute("data-topic", "1");
  });

  test("resolves groups and categories the server did not send", async function (assert) {
    const content = {
      colrender: { 0: "group", 1: "category" },
      relations: { group: [], category: [] },
      result_count: 1,
      columns: ["group_id", "category_id"],
      rows: [[1, 3]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(`${cell(1, 1)} a`)
      .hasText("admins", "resolves the group from the site");
    assert
      .dom(`${cell(1, 2)} .badge-category__name`)
      .hasText("meta", "resolves the category from the site");
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

    assert.dom(`${cell(1, 1)} .badge-category__name`).exists();
  });
});

module("Integration | Component | QueryResult | Chart", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the chart by default and the toggle for chartable results", async function (assert) {
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

    assert.dom("canvas").exists("the chart was rendered by default");
    assert
      .dom(".query-results-modes")
      .exists("the chart/table toggle is rendered");

    await click(".query-results-modes input[value='table']");

    assert.dom("table").exists("table renders after switching view");
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

  test("defaults to the table when charting would drop columns", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user", "reason", "count"],
      rows: [
        ["user1", "spam", 10],
        ["user2", "off-topic", 5],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom("table")
      .exists("table is the default when some columns can't be charted");
    assert.dom("canvas").doesNotExist("chart is not shown by default");

    await click(".query-results-modes input[value='chart']");
    assert.dom("canvas").exists("chart is still available via the toggle");
  });

  test("defaults to the table for large categorical result sets", async function (assert) {
    const rows = Array.from({ length: 200 }, (_, i) => [`item-${i + 1}`, i]);
    const content = {
      colrender: [],
      result_count: rows.length,
      columns: ["name", "count"],
      rows,
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom("table")
      .exists("table is the default for a large categorical result set");
    assert.dom("canvas").doesNotExist("chart is not shown by default");

    await click(".query-results-modes input[value='chart']");

    assert.dom("canvas").exists("chart remains available via the toggle");
  });

  test("defaults to the chart for large date-based result sets", async function (assert) {
    const rows = Array.from({ length: 200 }, (_, i) => [
      new Date(Date.UTC(2024, 0, i + 1)).toISOString().slice(0, 10),
      i,
    ]);
    const content = {
      colrender: [],
      result_count: rows.length,
      columns: ["date", "count"],
      rows,
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").exists("time series remain chart-first by default");
  });

  test("defaults to the table for sparse multi-series result sets", async function (assert) {
    const content = {
      colrender: [],
      result_count: 6,
      columns: ["name", "unassignable", "stale", "super_stale"],
      rows: [
        ["JVM", 4, "", 19],
        ["CFamily", "", "", ""],
        ["DataMachineLearning", "", "", ""],
        ["DotNET", 2, "", 3],
        ["TaintAnalysis", 4, 1, 4],
        ["Web", "", "", ""],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom("table")
      .exists("table is the default for sparse multi-series data");
    assert.dom("canvas").doesNotExist("chart is not shown by default");

    await click(".query-results-modes input[value='chart']");

    assert.dom("canvas").exists("chart remains available via the toggle");
  });

  test("defaults to the table for wide date-based multi-series result sets", async function (assert) {
    const numericColumns = Array.from(
      { length: 10 },
      (_metric, index) => `metric_${index + 1}`
    );
    const rows = Array.from({ length: 12 }, (_row, rowIndex) => [
      new Date(Date.UTC(2024, rowIndex, 1)).toISOString().slice(0, 10),
      ...numericColumns.map(
        (_column, columnIndex) => rowIndex + columnIndex + 1
      ),
    ]);
    const content = {
      colrender: [],
      result_count: rows.length,
      columns: ["date", ...numericColumns],
      rows,
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom("table")
      .exists("table is the default for too many time-series metrics");
    assert.dom("canvas").doesNotExist("chart is not shown by default");

    await click(".query-results-modes input[value='chart']");

    assert.dom("canvas").exists("chart remains available via the toggle");
    assert
      .dom(".query-results-chart__form input[value='stacked']")
      .exists("stacked chart remains available");
    assert
      .dom(".query-results-chart__form input[value='dual-axis']")
      .doesNotExist("dual-axis is not offered for more than two metrics");
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

  test("renders charts with null label values", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name", "like_count"],
      rows: [
        [null, 10],
        ["user2", 20],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom("canvas").exists("renders a chart canvas");
  });

  test("charts NULL cells as gaps", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["name", "count"],
      rows: [
        ["a", 1],
        ["b", null],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.deepEqual(
      (await chartData()).datasets[0].data,
      [1, null],
      "NULL is a gap rather than NaN"
    );
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

  test("uses sensible chart form defaults for common result shapes", async function (assert) {
    const cases = [
      {
        description: "text, number",
        columns: ["name", "count"],
        rows: [
          ["alpha", 10],
          ["beta", 20],
        ],
        selected: "bar",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
      {
        description: "date, number",
        columns: ["date", "count"],
        rows: [
          ["2024-01-01", 10],
          ["2024-01-02", 20],
        ],
        selected: "line",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
      {
        description: "month day, number",
        columns: ["date", "count"],
        rows: [
          ["Jan 01", 10],
          ["Jan 02", 20],
        ],
        selected: "line",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
      {
        description: "month year, number",
        columns: ["date", "count"],
        rows: [
          ["Jan 24", 10],
          ["Feb 24", 20],
        ],
        selected: "line",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
      {
        description: "text, number, number",
        columns: ["name", "likes", "posts"],
        rows: [
          ["alpha", 10, 5],
          ["beta", 20, 15],
        ],
        selected: "bar",
        available: ["line", "bar", "stacked"],
        unavailable: ["dual-axis"],
      },
      {
        description: "date, number, number",
        columns: ["date", "likes", "posts"],
        rows: [
          ["2024-01-01", 10, 5],
          ["2024-01-02", 20, 15],
        ],
        selected: "line",
        available: ["line", "bar", "stacked", "dual-axis"],
        unavailable: [],
      },
      {
        description: "date, number, number, number",
        columns: ["date", "likes", "posts", "topics"],
        rows: [
          ["2024-01-01", 10, 5, 1],
          ["2024-01-02", 20, 15, 2],
        ],
        selected: "line",
        available: ["line", "bar", "stacked"],
        unavailable: ["dual-axis"],
      },
      {
        description: "date, text, number",
        columns: ["date", "note", "count"],
        rows: [
          ["2024-01-01", "alpha", 10],
          ["2024-01-02", "beta", 20],
        ],
        selected: "line",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
      {
        description: "text, date, number",
        columns: ["name", "date", "count"],
        rows: [
          ["alpha", "2024-01-01", 10],
          ["beta", "2024-01-02", 20],
        ],
        selected: "bar",
        available: ["line", "bar"],
        unavailable: ["stacked", "dual-axis"],
      },
    ];

    for (const testCase of cases) {
      this.set("content", {
        colrender: [],
        result_count: testCase.rows.length,
        columns: testCase.columns,
        rows: testCase.rows,
      });

      await render(
        <template>
          <QueryResult @content={{this.content}} @view="chart" />
        </template>
      );

      assert
        .dom(`.query-results-chart__form input[value='${testCase.selected}']`)
        .isChecked(`${testCase.description} defaults to ${testCase.selected}`);

      for (const chartForm of testCase.available) {
        assert
          .dom(`.query-results-chart__form input[value='${chartForm}']`)
          .exists(`${testCase.description} offers ${chartForm}`);
      }

      for (const chartForm of testCase.unavailable) {
        assert
          .dom(`.query-results-chart__form input[value='${chartForm}']`)
          .doesNotExist(`${testCase.description} does not offer ${chartForm}`);
      }
    }
  });

  test("allows the chart form to be changed for date-based multi-series data", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["date", "likes", "posts"],
      rows: [
        ["2024-01-01", 10, 5],
        ["2024-01-02", 20, 15],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(".query-results-chart__form input[value='line']")
      .isChecked("date-based multi-series data defaults to a line chart");
    assert
      .dom(".query-results-chart__form input[value='dual-axis']")
      .exists("two-metric time series can use a dual-axis line chart");

    await click(".query-results-chart__form input[value='stacked']");

    assert
      .dom(".query-results-chart__form input[value='stacked']")
      .isChecked("the user can switch to stacked bars");
    assert.dom("canvas").exists("the chart remains visible");
  });

  test("does not offer a dual-axis chart for non-date multi-series data", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user", "likes", "posts"],
      rows: [
        ["user1", 10, 5],
        ["user2", 20, 15],
      ],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert
      .dom(".query-results-chart__form input[value='dual-axis']")
      .doesNotExist("dual-axis is only offered for date-based data");
  });

  test("persists the selected chart form per query", async function (assert) {
    const query = { id: 43 };
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["date", "likes", "posts"],
      rows: [
        ["2024-01-01", 10, 5],
        ["2024-01-02", 20, 15],
      ],
    };

    await render(
      <template><QueryResult @content={{content}} @query={{query}} /></template>
    );

    await click(".query-results-chart__form input[value='dual-axis']");

    await render(
      <template><QueryResult @content={{content}} @query={{query}} /></template>
    );

    assert
      .dom(".query-results-chart__form input[value='dual-axis']")
      .isChecked("chart form is restored from localStorage");
  });

  test("charts numeric columns and ignores text columns alongside them", async function (assert) {
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

    await click(".query-results-modes input[value='chart']");

    assert.dom("canvas").exists("renders the chart for numeric columns");
    assert
      .dom(".query-results-chart__footnote")
      .exists("shows a footnote listing ignored columns");
  });

  test("caps a long table and reveals it with the expand button", async function (assert) {
    const rows = Array.from({ length: 100 }, (_, i) => [`user${i}`, i]);
    const content = {
      colrender: [],
      result_count: rows.length,
      columns: ["user_name", "like_count"],
      rows,
    };

    await render(
      <template>
        <div class="query-results">
          <QueryResult @content={{content}} @view="table" />
        </div>
      </template>
    );

    assert
      .dom(".query-results-table-wrapper")
      .doesNotHaveClass("--expanded", "the long table is capped by default");
    assert
      .dom(".query-results-expand-btn")
      .exists("an expand button is offered for the overflowing table");

    await click(".query-results-expand-btn");

    assert
      .dom(".query-results-table-wrapper.--expanded")
      .exists("clicking expand removes the height cap");
    assert
      .dom(".query-results-expand-btn")
      .doesNotExist("the expand button is gone once expanded");
  });

  test("chart/table toggle switches the view (XOR)", async function (assert) {
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
      .dom("canvas")
      .exists("chart is visible by default for chartable data");
    assert.dom("table").doesNotExist("table hidden when chart is shown");

    await click(".query-results-modes input[value='table']");
    assert.dom("table").exists("table shown after switching");
    assert.dom("canvas").doesNotExist("chart hidden when table is shown");

    await click(".query-results-modes input[value='chart']");
    assert.dom("canvas").exists("chart shown after switching back");
    assert.dom("table").doesNotExist("table hidden again");
  });

  test("persists view per query in localStorage", async function (assert) {
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

    await click(".query-results-modes input[value='table']");
    assert.dom("table").exists("table shown after switching");
    assert.dom("canvas").doesNotExist("chart is hidden");

    await render(
      <template><QueryResult @content={{content}} @query={{query}} /></template>
    );

    assert.dom("table").exists("table view restored from localStorage");
    assert.dom("canvas").doesNotExist("chart still hidden after rerender");
  });

  test("toggle is always visible when rows exist (even for non-chartable data)", async function (assert) {
    const content = {
      colrender: [],
      result_count: 2,
      columns: ["user_name"],
      rows: [["user1"], ["user2"]],
    };

    await render(<template><QueryResult @content={{content}} /></template>);

    assert.dom(".query-results-modes").exists("toggle is always shown");

    await click(".query-results-modes input[value='chart']");
    assert
      .dom(".query-chart-empty-state")
      .exists("shows empty state for non-chartable data");
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
