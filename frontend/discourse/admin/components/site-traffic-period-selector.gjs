import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CustomDateRangeModal from "discourse/admin/components/modal/custom-date-range";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export const SITE_TRAFFIC_PERIODS = {
  LAST_7_DAYS: "last_7_days",
  LAST_30_DAYS: "last_30_days",
  LAST_90_DAYS: "last_90_days",
  LAST_12_MONTHS: "last_12_months",
  CUSTOM: "custom",
};

export default class SiteTrafficPeriodSelector extends Component {
  @service modal;

  get options() {
    return [
      {
        id: SITE_TRAFFIC_PERIODS.LAST_7_DAYS,
        name: i18n("admin.dashboard.site_traffic.periods.last_7_days"),
      },
      {
        id: SITE_TRAFFIC_PERIODS.LAST_30_DAYS,
        name: i18n("admin.dashboard.site_traffic.periods.last_30_days"),
      },
      {
        id: SITE_TRAFFIC_PERIODS.LAST_90_DAYS,
        name: i18n("admin.dashboard.site_traffic.periods.last_90_days"),
      },
      {
        id: SITE_TRAFFIC_PERIODS.LAST_12_MONTHS,
        name: i18n("admin.dashboard.site_traffic.periods.last_12_months"),
      },
      {
        id: SITE_TRAFFIC_PERIODS.CUSTOM,
        name: i18n("admin.dashboard.site_traffic.periods.custom"),
      },
    ];
  }

  @action
  onPeriodChange(period) {
    if (period === SITE_TRAFFIC_PERIODS.CUSTOM) {
      this.modal.show(CustomDateRangeModal, {
        model: {
          startDate: this.args.startDate,
          endDate: this.args.endDate,
          setCustomDateRange: this.args.setCustomDateRange,
        },
      });
      return;
    }
    this.args.setPeriod(period);
  }

  <template>
    <ComboBox
      class="site-traffic-period-selector__combo"
      @valueProperty="id"
      @nameProperty="name"
      @value={{@period}}
      @content={{this.options}}
      @onChange={{this.onPeriodChange}}
    />
  </template>
}
