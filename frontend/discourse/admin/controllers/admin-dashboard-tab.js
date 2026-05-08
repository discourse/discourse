import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";

export default class AdminDashboardTabController extends Controller {
  @controller("admin.dashboard") dashboardController;

  @tracked period = "monthly";
  queryParams = ["period"];

  get start_date() {
    return this.dashboardController.start_date;
  }

  set start_date(value) {
    this.dashboardController.start_date = value;
  }

  get end_date() {
    return this.dashboardController.end_date;
  }

  set end_date(value) {
    this.dashboardController.end_date = value;
  }

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
