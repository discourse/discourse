import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";

// args:
// chartConfig - object
export default class Chart extends Component {
  renderChart = modifier((element) => {
    const { chartConfig, loadChartDataLabelsPlugin } = this.args;

    loadScript("/javascripts/Chart.min.js")
      .then(
        () =>
          loadChartDataLabelsPlugin &&
          loadScript("/javascripts/chartjs-plugin-datalabels.min.js")
      )
      .then(() => {
        if (loadChartDataLabelsPlugin) {
          (chartConfig.plugins ??= []).push(window.ChartDataLabels);
        }
        this.chart = new window.Chart(element.getContext("2d"), chartConfig);
      });

    return () => this.chart?.destroy();
  });

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
