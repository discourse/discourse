import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import loadChartJS, {
  loadChartJSDatalabels,
} from "discourse/lib/load-chart-js";

// args:
// chartConfig - object
export default class ChartComponent extends Component {
  renderChart = modifier((element) => {
    this.loadAndInit(element);
    return () => this.chart?.destroy();
  });

  async loadAndInit(element) {
    const chartConfig = { ...this.args.chartConfig };

    const Chart = await loadChartJS();

    if (this.args.loadChartDataLabelsPlugin) {
      const ChartDataLabelsPlugin = await loadChartJSDatalabels();
      chartConfig.plugins = [
        ...(chartConfig.plugins || []),
        ChartDataLabelsPlugin,
      ];
    }

    this.chart = new Chart(element.getContext("2d"), chartConfig);
  }

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
