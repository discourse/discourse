import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { makeArray } from "discourse-common/lib/helpers";
import { bind } from "discourse-common/utils/decorators";
import Report from "admin/models/report";

@classNames("admin-report-chart", "admin-report-radar")
export default class AdminReportRadar extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    window.addEventListener("resize", this._resizeHandler);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    window.removeEventListener("resize", this._resizeHandler);
    this._resetChart();
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    discourseDebounce(this, this._scheduleChartRendering, 100);
  }

  @bind
  _resizeHandler() {
    discourseDebounce(this, this._scheduleChartRendering, 500);
  }

  _scheduleChartRendering() {
    schedule("afterRender", () => {
      if (!this.element) {
        return;
      }

      this._renderChart(
        this.model,
        this.element.querySelector(".chart-canvas")
      );
    });
  }

  _renderChart(model, chartCanvas) {
    if (!chartCanvas) {
      return;
    }

    const context = chartCanvas.getContext("2d");

    const chartData = makeArray(model.chartData || model.data).map((cd) => {
      return {
        label: cd.label,
        color: cd.color,
        data: Report.collapse(model, cd.data),
      };
    });

    const data = {
      labels: chartData[0].data.mapBy("x"),
      datasets: chartData.map((cd) => {
        return {
          label: cd.label,
          data: cd.data.mapBy("y"),
          fill: true,
          backgroundColor: this._hexToRGBA(cd.color, 0.3),
          borderColor: cd.color,
          pointBackgroundColor: cd.color,
          pointBorderColor: "#fff",
          pointHoverBackgroundColor: "#fff",
          pointHoverBorderColor: cd.color,
        };
      }),
    };

    loadScript("/javascripts/Chart.min.js").then(() => {
      this._resetChart();

      this._chart = new window.Chart(context, this._buildChartConfig(data));
    });
  }

  _buildChartConfig(data) {
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
                let total = 0;
                tooltipItem.forEach(
                  (item) => (total += parseInt(item.parsed.r || 0, 10))
                );
                return `= ${total}`;
              },
            },
          },
        },
      },
    };
  }

  _resetChart() {
    this._chart?.destroy();
    this._chart = null;
  }

  _hexToRGBA(hexCode, opacity) {
    let hex = hexCode.replace("#", "");

    if (hex.length === 3) {
      hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    }

    const r = parseInt(hex.substring(0, 2), 16),
      g = parseInt(hex.substring(2, 4), 16),
      b = parseInt(hex.substring(4, 6), 16);

    return `rgba(${r},${g},${b}, ${opacity})`;
  }
}
