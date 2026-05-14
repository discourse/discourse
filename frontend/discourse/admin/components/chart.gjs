import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import loadChartJS, {
  loadChartJSDatalabels,
} from "discourse/lib/load-chart-js";

// args:
// chartConfig - object passed to Chart.js
// rebuildKey - optional value that recreates the Chart.js instance when changed
// onReady - optional callback invoked with the Chart.js instance after render
export default class ChartComponent extends Component {
  renderChart = modifier((element, [rebuildKey]) => {
    let chart;
    let cancelled = false;

    const isCancelled = () => cancelled || rebuildKey !== this.args.rebuildKey;

    this.loadAndInit(element, isCancelled).then((loadedChart) => {
      if (!loadedChart) {
        return;
      }

      if (isCancelled()) {
        loadedChart.destroy();
        return;
      }

      chart = loadedChart;
      this.args.onReady?.(loadedChart, element);
    });

    return () => {
      cancelled = true;
      chart?.destroy();

      if (this.chart === chart) {
        this.chart = null;
      }
    };
  });

  async loadAndInit(element, isCancelled) {
    const chartConfig = { ...this.args.chartConfig };

    const Chart = await loadChartJS();

    if (this.args.loadChartDataLabelsPlugin) {
      const ChartDataLabelsPlugin = await loadChartJSDatalabels();
      chartConfig.plugins = [
        ...(chartConfig.plugins || []),
        ChartDataLabelsPlugin,
      ];
    }

    if (isCancelled()) {
      return;
    }

    this.chart = new Chart(element.getContext("2d"), chartConfig);

    return this.chart;
  }

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas {{this.renderChart @rebuildKey}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
