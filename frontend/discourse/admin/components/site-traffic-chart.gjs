import Component from "@glimmer/component";
import AdminReportStackedChart from "discourse/admin/components/admin-report-stacked-chart";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { i18n } from "discourse-i18n";

export default class SiteTrafficChart extends Component {
  get intervalValue() {
    return this.args.grouping ?? this.args.effectiveBucket;
  }

  get intervalItems() {
    return [
      {
        value: "hour",
        label: i18n("admin.site_traffic_explorer.interval.options.hour"),
      },
      {
        value: "day",
        label: i18n("admin.site_traffic_explorer.interval.options.day"),
      },
    ];
  }

  <template>
    <div class="site-traffic-chart">
      <div class="site-traffic-chart__canvas">
        <AdminReportStackedChart
          @model={{@model}}
          @options={{@options}}
          class="db-section__traffic-chart-canvas"
        />
      </div>
      <DSegmentedControl
        class="site-traffic-chart__interval"
        @name="site-traffic-chart-interval"
        @label="admin.site_traffic_explorer.interval.label"
        @items={{this.intervalItems}}
        @value={{this.intervalValue}}
        @onSelect={{@onIntervalChange}}
        data-test-site-traffic-interval
      />
    </div>
  </template>
}
