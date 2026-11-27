import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import loadChartJS, {
  loadChartJSDatalabels,
} from "discourse/lib/load-chart-js";

// args:
// chartConfig - object
export default class ChartComponent extends Component {
  renderChart = modifier((element) => {
    let cancelled = false;
    this.loadAndInit(element, () => cancelled);
    return () => {
      cancelled = true;
      this.chart?.destroy();
      this.chart = null;
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
  }

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas class="chart-canvas" {{this.renderChart}}></canvas>
      </div>
    </div>
  </template>
}
