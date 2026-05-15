import Component from "@glimmer/component";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";

export default class DashboardTrafficChart extends Component {
  get chartModel() {
    return {
      start_date: this.args.startDate,
      end_date: this.args.endDate,
      data: this.args.traffic?.pageview_series ?? [],
    };
  }

  get chartOptions() {
    return {
      borderRadius: 0,
      hiddenLabels: ["page_view_crawler"],
      legendAlign: "center",
      legendDisplay: this.chartModel.data.length > 1,
      legendLabelPadding: null,
      legendPosition: "top",
      maxBarThickness: 28,
      skipCollapse: true,
      stack: "site-traffic",
      timeUnit: this.timeUnit,
      tooltipTitle: (items) => this.#formatTooltipTitle(items[0].raw),
      useGradient: false,
    };
  }

  get timeUnit() {
    const firstPoint = this.chartModel.data[0]?.data?.[0];

    if (!firstPoint?.end_date) {
      return "day";
    }

    const bucketDays =
      moment(firstPoint.end_date).diff(moment(firstPoint.x), "days") + 1;

    if (bucketDays >= 28) {
      return "month";
    }

    if (bucketDays > 1) {
      return "week";
    }

    return "day";
  }

  #formatTooltipTitle(point) {
    const startDate = moment(point.x);
    const endDate = moment(point.end_date || point.x);

    if (startDate.isSame(endDate, "day")) {
      return startDate.format("ddd, D MMM YYYY");
    }

    if (startDate.year() !== endDate.year()) {
      return `${startDate.format("D MMM YYYY")} - ${endDate.format("D MMM YYYY")}`;
    }

    return `${startDate.format("D MMM")} - ${endDate.format("D MMM YYYY")}`;
  }

  <template>
    <div class="db-section__traffic-chart">
      <AdminReportStackedChart
        @model={{this.chartModel}}
        @options={{this.chartOptions}}
        @rebuildKey={{@traffic}}
        class="db-section__traffic-chart-canvas"
      />
    </div>
  </template>
}
