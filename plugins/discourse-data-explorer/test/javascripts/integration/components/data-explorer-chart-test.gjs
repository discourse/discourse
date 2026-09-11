import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadChartJS from "discourse/lib/load-chart-js";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DataExplorerChart from "discourse/plugins/discourse-data-explorer/discourse/components/data-explorer-chart";

const AfterRender = <template>
  <div {{didInsert (fn schedule "afterRender" @run)}}></div>
</template>;

module("Integration | Component | DataExplorerChart", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a bar chart with a single dataset", async function (assert) {
    const labels = ["label_1", "label_2"];
    const datasets = [{ label: "data", values: [115, 1000] }];

    await render(
      <template>
        <DataExplorerChart
          @chartType="bar"
          @datasets={{datasets}}
          @labels={{labels}}
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
          @chartType="line"
          @datasets={{datasets}}
          @labels={{labels}}
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
          @chartType="bar"
          @datasets={{datasets}}
          @labels={{labels}}
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
          @chartType="bar"
          @datasets={{datasets}}
          @labels={{labels}}
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
          @chartType="line"
          @datasets={{datasets}}
          @dualAxis={{true}}
          @labels={{labels}}
          @stacked={{false}}
        />
      </template>
    );

    assert.dom("canvas").exists("renders a canvas for dual-axis chart");
  });

  test("re-rendering before the chart library loads creates a single chart", async function (assert) {
    class State {
      @tracked labels = ["a", "b"];
    }

    const state = new State();
    const datasets = [{ label: "count", values: [1, 2] }];
    const relabel = () => (state.labels = ["c", "d"]);
    const Chart = await loadChartJS();

    await render(
      <template>
        <DataExplorerChart
          @chartType="bar"
          @datasets={{datasets}}
          @labels={{state.labels}}
          @stacked={{false}}
        />
        <AfterRender @run={{relabel}} />
      </template>
    );

    const canvas = find("canvas");

    assert.deepEqual(
      Chart.getChart(canvas).data.labels,
      ["c", "d"],
      "the chart reflects the latest labels"
    );
    assert.strictEqual(
      Object.values(Chart.instances).filter((chart) => chart.canvas === canvas)
        .length,
      1,
      "a single chart is bound to the canvas"
    );
  });

  test("does not build a chart when destroyed before the chart library loads", async function (assert) {
    class State {
      @tracked shown = true;
    }

    const state = new State();
    const datasets = [{ label: "count", values: [1, 2] }];
    const labels = ["a", "b"];
    const hide = () => (state.shown = false);
    const Chart = await loadChartJS();
    const before = Object.keys(Chart.instances).length;

    await render(
      <template>
        {{#if state.shown}}
          <DataExplorerChart
            @chartType="bar"
            @datasets={{datasets}}
            @labels={{labels}}
            @stacked={{false}}
          />
        {{/if}}
        <AfterRender @run={{hide}} />
      </template>
    );

    assert.strictEqual(
      Object.keys(Chart.instances).length,
      before,
      "no chart survives the destroyed component"
    );
  });
});
