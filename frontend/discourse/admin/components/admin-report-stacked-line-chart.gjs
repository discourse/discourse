import Component from "@glimmer/component";
import hexToRGBA from "discourse/admin/lib/hex-to-rgba";
import Report from "discourse/admin/models/report";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import Chart from "./chart";

export default class AdminReportStackedLineChart extends Component {
  get chartConfig() {
    const { model } = this.args;

    const chartData = makeArray(model.chartData || model.data).map(
      (series) => ({
        label: series.label,
        color: series.color,
        data: Report.collapse(model, series.data),
      })
    );

    return {
      type: "line",
      data: {
        labels: chartData[0].data.map((point) => point.x),
        datasets: chartData.map((series) => ({
          label: series.label,
          stack: "pageviews-stack",
          data: series.data,
          fill: true,
          backgroundColor: hexToRGBA(series.color, 0.3),
          borderColor: series.color,
          pointBackgroundColor: series.color,
          pointBorderColor: "#fff",
          pointHoverBackgroundColor: "#fff",
          pointHoverBorderColor: series.color,
        })),
      },
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
                  (sum, item) => sum + parseInt(item.parsed.y || 0, 10),
                  0
                );
                return `= ${total}`;
              },
              title: (tooltipItem) =>
                moment(tooltipItem[0].parsed.x).format("LL"),
            },
          },
        },

        layout: {
          padding: {
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
          },
        },
        scales: {
          y: {
            stacked: true,
            display: true,
            ticks: {
              callback: (label) => number(label),
              sampleSize: 5,
              maxRotation: 25,
              minRotation: 25,
            },
          },
          x: {
            stacked: true,
            display: true,
            grid: { display: false },
            type: "time",
            time: {
              unit: Report.unitForDatapoints(chartData[0].data.length),
            },
            ticks: {
              sampleSize: 5,
              maxRotation: 50,
              minRotation: 50,
            },
          },
        },
      },
    };
  }

  <template>
    <Chart
      @chartConfig={{this.chartConfig}}
      class="admin-report-chart admin-report-stacked-line-chart"
    />
  </template>
}
