import Component from "@glimmer/component";
import Report from "discourse/admin/models/report";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import Chart from "./chart";

export default class AdminReportStackedChart extends Component {
  get chartConfig() {
    const { model } = this.args;

    const options = this.args.options || {};
    options.hiddenLabels ??= [];

    const chartData = makeArray(model.chartData || model.data).map(
      (series) => ({
        label: series.label,
        color: series.color,
        data: Report.collapse(model, series.data),
        req: series.req,
      })
    );

    const data = {
      labels: chartData[0].data.map((point) => point.x),
      datasets: chartData.map((series) => ({
        label: series.label,
        stack: "pageviews-stack",
        data: series.data,
        backgroundColor: series.color,
        hidden: options.hiddenLabels.includes(series.req),
      })),
    };

    return {
      type: "bar",
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
              unit: Report.unitForDatapoints(data.labels.length),
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
      class="admin-report-chart admin-report-stacked-chart"
    />
  </template>
}
