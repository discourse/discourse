import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import Chart from "admin/components/chart";

export default class DoughnutChart extends Component {
  @tracked canvasSize = null;

  get config() {
    const totalScore = this.args.totalScore || "";

    return {
      type: "doughnut",
      data: {
        labels: this.args.labels,
        datasets: [
          {
            data: this.args.data,
            backgroundColor: this.args.colors,
            cutout: "50%",
            radius: 100,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: this.args.displayLegend || false,
            position: "bottom",
          },
        },
      },
      plugins: [
        {
          id: "centerText",
          afterDraw: function (chart) {
            const cssVarColor =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--primary-high"
              ) || "#000";
            const cssFontSize =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-up-4"
              ) || "1.3em";
            const cssFontFamily =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-family"
              ) || "sans-serif";

            const { ctx, chartArea } = chart;
            const centerX = (chartArea.left + chartArea.right) / 2;
            const centerY = (chartArea.top + chartArea.bottom) / 2;

            ctx.restore();
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillStyle = cssVarColor.trim();
            ctx.font = `bold ${cssFontSize.trim()} ${cssFontFamily.trim()}`;

            ctx.fillText(totalScore, centerX, centerY);
            ctx.save();
          },
        },
        {
          // Custom plugin to draw labels inside the doughnut chart
          id: "doughnutLabels",
          afterDraw(chart) {
            const ctx = chart.ctx;
            const dataset = chart.data.datasets[0];
            const meta = chart.getDatasetMeta(0);
            const cssFontSize =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-down-2"
              ) || "1.3em";
            const cssFontFamily =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-family"
              ) || "sans-serif";

            ctx.font = `${cssFontSize.trim()} ${cssFontFamily.trim()}`;
            ctx.fillStyle = "#fafafa";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            meta.data.forEach((element, index) => {
              const { x, y } = element.tooltipPosition();
              const value = dataset.data[index];
              const nonZeroCount = dataset.data.filter((v) => v > 0).length;

              if (value === 0 || nonZeroCount === 1) {
                return;
              }

              ctx.fillText(value, x, y);
            });
          },
        },
      ],
    };
  }

  <template>
    {{#if this.config}}
      <h3 class="doughnut-chart-title">{{@doughnutTitle}}</h3>
      <Chart @chartConfig={{this.config}} class="admin-report-doughnut" />
    {{/if}}
  </template>
}
