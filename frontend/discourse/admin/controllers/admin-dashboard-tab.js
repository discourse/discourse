import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminDashboardTabController extends Controller {
  @tracked period = "monthly";
  @tracked start_date = null;
  @tracked end_date = null;
  queryParams = ["period", "start_date", "end_date"];

  get startDate() {
    if (this.start_date) {
      return moment.utc(this.start_date).locale("en").startOf("day");
    }
    return this.#calculateStartDate();
  }

  get endDate() {
    if (this.end_date) {
      return moment.utc(this.end_date).locale("en").endOf("day");
    }
    return moment().locale("en").utc().endOf("day");
  }

  get filters() {
    return {
      startDate: this.startDate,
      endDate: this.endDate,
    };
  }

  #calculateStartDate() {
    const fullDay = moment().locale("en").utc().endOf("day");

    switch (this.period) {
      case "yearly":
        return fullDay.subtract(1, "year").startOf("day");
      case "quarterly":
        return fullDay.subtract(3, "month").startOf("day");
      case "weekly":
        return fullDay.subtract(6, "days").startOf("day");
      default:
        return fullDay.subtract(1, "month").startOf("day");
    }
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.period = "custom";
    this.start_date = moment(startDate).format("YYYY-MM-DD");
    this.end_date = moment(endDate).format("YYYY-MM-DD");
  }

  @action
  setPeriod(period) {
    this.period = period;
    this.start_date = null;
    this.end_date = null;
  }
}
