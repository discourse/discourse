import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import loadChartJS, {
  loadChartJSDatalabels,
} from "discourse/lib/load-chart-js";

// args:
// chartConfig - object
export default class ChartComponent extends Component {
  renderChart = modifier((element) => {
    const renderVersion = ++this.#renderVersion;
    let cancelled = false;
    let chart;
    this.loadAndInit(element, () => this.#renderVersion === renderVersion).then(
      (initializedChart) => {
        if (!initializedChart) {
          return;
        }
        if (cancelled) {
          initializedChart.destroy();
          return;
        }

        chart = initializedChart;
        this.chart = initializedChart;
        this.args.onChartReady?.(initializedChart);
      }
    );
    return () => {
      cancelled = true;
      if (this.#renderVersion === renderVersion) {
        this.#renderVersion++;
      }
      chart?.destroy();
      if (this.chart === chart) {
        this.chart = null;
      }
    };
  });
  #renderVersion = 0;

  async loadAndInit(element, isCurrent) {
    const chartConfig = { ...this.args.chartConfig };

    const Chart = await loadChartJS();

    if (this.args.loadChartDataLabelsPlugin) {
      const ChartDataLabelsPlugin = await loadChartJSDatalabels();
      chartConfig.plugins = [
        ...(chartConfig.plugins || []),
        ChartDataLabelsPlugin,
      ];
    }

    if (!isCurrent()) {
      return;
    }

    return new Chart(element.getContext("2d"), chartConfig);
  }

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
