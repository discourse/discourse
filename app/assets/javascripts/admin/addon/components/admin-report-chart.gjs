import Component from "@glimmer/component";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import Report from "admin/models/report";
import Chart from "./chart";

export default class AdminReportChart extends Component {
  get chartConfig() {
    const { model, options } = this.args;

    const chartData = Report.collapse(
      model,
      makeArray(model.chartData || model.data, "weekly"),
      options.chartGrouping
    );
    const prevChartData = makeArray(model.prevChartData || model.prev_data);
    const labels = chartData.map((d) => d.x);

    const data = {
      labels,
      datasets: [
        {
          data: chartData.map((d) => Math.round(parseFloat(d.y))),
          backgroundColor: prevChartData.length
            ? "transparent"
            : model.secondary_color,
          borderColor: model.primary_color,
          pointRadius: 3,
          borderWidth: 1,
          pointBackgroundColor: model.primary_color,
          pointBorderColor: model.primary_color,
        },
      ],
    };

    if (prevChartData.length) {
      data.datasets.push({
        data: prevChartData.map((d) => Math.round(parseFloat(d.y))),
        borderColor: model.primary_color,
        borderDash: [5, 5],
        backgroundColor: "transparent",
        borderWidth: 1,
        pointRadius: 0,
      });
    }

    return {
      type: "line",
      data,
      options: {
        plugins: {
          tooltip: {
            callbacks: {
              title: (tooltipItem) =>
                moment(tooltipItem[0].label, "YYYY-MM-DD").format("LL"),
            },
          },
          legend: {
            display: false,
          },
        },
        responsive: true,
        maintainAspectRatio: false,
        responsiveAnimationDuration: 0,
        animation: {
          duration: 0,
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
          y: [
            {
              display: true,
              ticks: {
                callback: (label) => number(label),
                sampleSize: 5,
                maxRotation: 25,
                minRotation: 25,
              },
            },
          ],
          x: [
            {
              display: true,
              gridLines: { display: false },
              type: "time",
              time: {
                unit: Report.unitForGrouping(options.chartGrouping),
              },
              ticks: {
                sampleSize: 5,
                maxRotation: 50,
                minRotation: 50,
              },
            },
          ],
        },
      },
    };
  }

  <template>
    <Chart @chartConfig={{this.chartConfig}} class="admin-report-chart" />
  </template>
}
