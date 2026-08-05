import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import {
  ALL_PRESETS,
  calculatePresetStartDate,
  PERIOD_CUSTOM,
} from "discourse/admin/lib/dashboard-date-range";

export default class AdminDashboardTrafficController extends Controller {
  @tracked start_date = null;
  @tracked end_date = null;

  queryParams = ["start_date", "end_date"];

  get startDate() {
    return moment(this.start_date, "YYYY-MM-DD", true).toDate();
  }

  get endDate() {
    return moment(this.end_date, "YYYY-MM-DD", true).toDate();
  }

  get period() {
    const startDate = moment(this.start_date, "YYYY-MM-DD", true);
    const endDate = moment(this.end_date, "YYYY-MM-DD", true);
    if (!startDate.isValid() || !endDate.isSame(moment(), "day")) {
      return PERIOD_CUSTOM;
    }

    return (
      ALL_PRESETS.find((period) =>
        startDate.isSame(calculatePresetStartDate(period), "day")
      ) ?? PERIOD_CUSTOM
    );
  }

  @action
  setPeriod(period) {
    this.start_date = moment(calculatePresetStartDate(period)).format(
      "YYYY-MM-DD"
    );
    this.end_date = moment().format("YYYY-MM-DD");
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
  }

  ensureDefaultRange() {
    if (
      moment(this.start_date, "YYYY-MM-DD", true).isValid() &&
      moment(this.end_date, "YYYY-MM-DD", true).isValid()
    ) {
      return;
    }

    this.start_date = moment(calculatePresetStartDate("last_30_days")).format(
      "YYYY-MM-DD"
    );
    this.end_date = moment().format("YYYY-MM-DD");
  }
}
