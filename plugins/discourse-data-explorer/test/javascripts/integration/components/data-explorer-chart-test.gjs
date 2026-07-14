import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DataExplorerChart from "../../discourse/components/data-explorer-chart";

module("Integration | Component | DataExplorerChart", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a bar chart with a single dataset", async function (assert) {
    const labels = ["label_1", "label_2"];
    const datasets = [{ label: "data", values: [115, 1000] }];

    await render(
      <template>
        <DataExplorerChart
          @labels={{labels}}
          @datasets={{datasets}}
          @chartType="bar"
          @stacked={{false}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas");
  });

  test("renders a line chart", async function (assert) {
    const labels = ["2024-01-01", "2024-01-02"];
    const datasets = [{ label: "count", values: [10, 20] }];

    await render(
      <template>
        <DataExplorerChart
          @labels={{labels}}
          @datasets={{datasets}}
          @chartType="line"
          @stacked={{false}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas for line chart");
  });

  test("renders a multi-series chart", async function (assert) {
    const labels = ["user1", "user2"];
    const datasets = [
      { label: "likes", values: [10, 20] },
      { label: "posts", values: [5, 15] },
    ];

    await render(
      <template>
        <DataExplorerChart
          @labels={{labels}}
          @datasets={{datasets}}
          @chartType="bar"
          @stacked={{false}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas for multi-series chart");
  });

  test("renders a stacked chart", async function (assert) {
    const labels = ["2024-01-01", "2024-01-02"];
    const datasets = [
      { label: "likes", values: [10, 20] },
      { label: "posts", values: [5, 15] },
    ];

    await render(
      <template>
        <DataExplorerChart
          @labels={{labels}}
          @datasets={{datasets}}
          @chartType="bar"
          @stacked={{true}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas for stacked chart");
  });

  test("renders a dual-axis line chart", async function (assert) {
    const labels = ["2024-01-01", "2024-01-02"];
    const datasets = [
      { label: "distinct_repliers", values: [263, 220] },
      { label: "replies_per_person", values: [6, 8] },
    ];

    await render(
      <template>
        <DataExplorerChart
          @labels={{labels}}
          @datasets={{datasets}}
          @chartType="line"
          @stacked={{false}}
          @dualAxis={{true}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas for dual-axis chart");
  });
});
