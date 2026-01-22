import Component from "@glimmer/component";
import Report from "discourse/admin/models/report";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import Chart from "./chart";

const DOTTED_LINE = [5, 5];

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

export function isInCurrentPeriod(timestamp, grouping) {
  const date = moment(timestamp);
  const now = moment();

  switch (grouping) {
    case "weekly":
      return date.isSame(now, "week");
    case "monthly":
      return date.isSame(now, "month");
    default:
      return date.isSame(now, "day");
  }
}

export function hasIncompleteData(lastPoint, grouping) {
  if (!lastPoint) {
    return false;
  }
  return isInCurrentPeriod(lastPoint.x, grouping);
}

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

    const lastDataPointIndex = chartData.length - 1;
    const lastDataPoint = chartData[lastDataPointIndex];
    const isLastPointInCurrentPeriod = hasIncompleteData(
      lastDataPoint,
      options.chartGrouping
    );

    const incompleteColor = getCSSColor("--primary-medium");
    let pointColors = model.primary_color;
    let segment;

    if (isLastPointInCurrentPeriod) {
      pointColors = Array(chartData.length).fill(model.primary_color);
      pointColors[lastDataPointIndex] = incompleteColor;

      const isIncompleteSegment = (ctx) =>
        ctx.p1DataIndex === lastDataPointIndex;
      segment = {
        borderDash: (ctx) => (isIncompleteSegment(ctx) ? DOTTED_LINE : []),
        borderColor: (ctx) =>
          isIncompleteSegment(ctx) ? incompleteColor : model.primary_color,
      };
    }

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
          pointBackgroundColor: pointColors,
          pointBorderColor: pointColors,
          segment,
        },
      ],
    };

    if (prevChartData.length) {
      data.datasets.push({
        data: prevChartData.map((d) => Math.round(parseFloat(d.y))),
        borderColor: model.primary_color,
        borderDash: DOTTED_LINE,
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
                moment(tooltipItem[0].parsed.x).format("LL"),
              label: (tooltipItem) => {
                const value = tooltipItem.formattedValue;
                if (
                  isLastPointInCurrentPeriod &&
                  tooltipItem.dataIndex === lastDataPointIndex
                ) {
                  return `${value} (${i18n("admin.dashboard.reports.so_far")})`;
                }
                return value;
              },
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
          y: {
            display: true,
            ticks: {
              callback: (label) => number(label),
              sampleSize: 5,
              maxRotation: 25,
              minRotation: 25,
            },
          },
          x: {
            display: true,
            grid: { display: false },
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
        },
      },
    };
  }

  <template>
    <Chart @chartConfig={{this.chartConfig}} class="admin-report-chart" />
  </template>
}
