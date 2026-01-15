import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse/lib/decorators";
import loadChartJS from "discourse/lib/load-chart-js";
import themeColor from "../lib/themeColor";

export default class DataExplorerBarChart extends Component {
  chart;
  barsColor = themeColor("--tertiary");
  barsHoverColor = themeColor("--tertiary-high");
  gridColor = themeColor("--primary-low");
  labelsColor = themeColor("--primary-medium");

  willDestroy() {
    super.willDestroy(...arguments);
    this.chart.destroy();
  }

  get config() {
    const data = this.data;
    const options = this.options;
    return {
      type: "bar",
      data,
      options,
    };
  }

  get data() {
    const labels = this.args.labels;
    return {
      labels,
      datasets: [
        {
          label: this.args.datasetName,
          data: this.args.values,
          backgroundColor: this.barsColor,
          hoverBackgroundColor: this.barsHoverColor,
        },
      ],
    };
  }

  get options() {
    return {
      plugins: {
        legend: {
          labels: {
            color: this.labelsColor,
          },
        },
      },
      scales: {
        x: {
          grid: {
            color: this.gridColor,
          },
          ticks: {
            color: this.labelsColor,
          },
        },
        y: {
          grid: {
            color: this.gridColor,
          },
          ticks: {
            beginAtZero: true,
            color: this.labelsColor,
          },
        },
      },
    };
  }

  @bind
  async initChart(canvas) {
    const Chart = await loadChartJS();
    const context = canvas.getContext("2d");
    this.chart = new Chart(context, this.config);
  }

  @action
  updateChartData() {
    this.chart.data = this.data;
    this.chart.update();
  }

  <template>
    <canvas
      {{didInsert this.initChart}}
      {{on "change" this.updateChartData}}
    ></canvas>
  </template>
}
