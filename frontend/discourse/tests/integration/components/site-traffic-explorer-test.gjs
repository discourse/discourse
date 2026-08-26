import { tracked } from "@glimmer/tracking";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteTrafficExplorer from "discourse/admin/components/site-traffic-explorer";
import loadChartJS from "discourse/lib/load-chart-js";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const TRAFFIC_TYPES = ["logged_in", "anonymous", "likely_crawler"];

class TestState {
  @tracked trafficTypes = TRAFFIC_TYPES;

  toggleTrafficType = (trafficType) => {
    this.trafficTypes = this.trafficTypes.includes(trafficType)
      ? this.trafficTypes.filter((selected) => selected !== trafficType)
      : [...this.trafficTypes, trafficType];
  };
}

module("Integration | Component | SiteTrafficExplorer", function (hooks) {
  setupRenderingTest(hooks);

  test("the chart legend reflects pending traffic type changes", async function (assert) {
    this.siteSettings.improved_crawler_detection = true;

    const state = new TestState();
    const traffic = {
      chart_traffic_types: TRAFFIC_TYPES,
      dimensions: {},
      series: [
        {
          date: "2026-08-25",
          logged_in_human_pageviews: 3,
          anonymous_human_pageviews: 2,
          likely_crawler_pageviews: 1,
        },
      ],
      summary: { pageviews: 6 },
    };

    await render(
      <template>
        <SiteTrafficExplorer
          @traffic={{traffic}}
          @hasPageviews={{true}}
          @period="last_30_days"
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
          @activeFilters={{this.activeFilters}}
          @trafficTypes={{state.trafficTypes}}
          @toggleTrafficType={{state.toggleTrafficType}}
        />
      </template>
    );

    const Chart = await loadChartJS();
    const canvas = find(".admin-report-stacked-chart canvas");
    const initialChart = Chart.getChart(canvas);
    const initialData = initialChart.data.datasets.map((dataset) => [
      ...dataset.data,
    ]);

    for (const datasetIndex of [0, 1, 2]) {
      let chart = Chart.getChart(canvas);
      chart.options.plugins.legend.onClick(
        undefined,
        { datasetIndex },
        { chart }
      );
      await settled();

      chart = Chart.getChart(canvas);
      assert.false(
        chart.isDatasetVisible(datasetIndex),
        `hides dataset ${datasetIndex} before filters are applied`
      );
      assert.deepEqual(
        chart.data.datasets.map((dataset) => [...dataset.data]),
        initialData,
        `keeps dataset ${datasetIndex} data unchanged before filters are applied`
      );

      chart.options.plugins.legend.onClick(
        undefined,
        { datasetIndex },
        { chart }
      );
      await settled();

      assert.true(
        Chart.getChart(canvas).isDatasetVisible(datasetIndex),
        `shows dataset ${datasetIndex} when selected again`
      );
    }
  });
});
