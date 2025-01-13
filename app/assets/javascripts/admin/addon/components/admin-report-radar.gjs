import Component from "@glimmer/component";
import { makeArray } from "discourse/lib/helpers";
import hexToRGBA from "admin/lib/hex-to-rgba";
import Report from "admin/models/report";
import Chart from "./chart";

export default class AdminReportRadar extends Component {
  get chartConfig() {
    const { model } = this.args;

    const chartData = makeArray(model.chartData || model.data).map((cd) => ({
      label: cd.label,
      color: cd.color,
      data: Report.collapse(model, cd.data),
    }));

    const data = {
      labels: chartData[0].data.mapBy("x"),
      datasets: chartData.map((cd) => ({
        label: cd.label,
        data: cd.data.mapBy("y"),
        fill: true,
        backgroundColor: hexToRGBA(cd.color, 0.3),
        borderColor: cd.color,
        pointBackgroundColor: cd.color,
        pointBorderColor: "#fff",
        pointHoverBackgroundColor: "#fff",
        pointHoverBorderColor: cd.color,
      })),
    };

    return {
      type: "radar",
      data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        responsiveAnimationDuration: 0,
        hover: { mode: "index" },
        animation: {
          duration: 0,
        },
        plugins: {
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              beforeFooter: (tooltipItem) => {
                const total = tooltipItem.reduce(
                  (sum, item) => sum + parseInt(item.parsed.r || 0, 10)
                );
                return `= ${total}`;
              },
            },
          },
        },
      },
    };
  }

  <template>
    <Chart
      @chartConfig={{this.chartConfig}}
      class="admin-report-chart admin-report-radar"
    />
  </template>
}
