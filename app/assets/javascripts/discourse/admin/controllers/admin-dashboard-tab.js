import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import CustomDateRangeModal from "../components/modal/custom-date-range";

export default class AdminDashboardTabController extends Controller {
  @service modal;

  @tracked endDate = moment().locale("en").utc().endOf("day");
  @tracked startDate = this.calculateStartDate();
  @tracked
  filters = new TrackedObject({
    startDate: this.startDate,
    endDate: this.endDate,
  });

  queryParams = ["period"];
  period = "monthly";

  calculateStartDate() {
    const fullDay = moment().locale("en").utc().endOf("day");

    switch (this.period) {
      case "yearly":
        return fullDay.subtract(1, "year").startOf("day");
      case "quarterly":
        return fullDay.subtract(3, "month").startOf("day");
      case "weekly":
        return fullDay.subtract(6, "days").startOf("day");
      case "monthly":
        return fullDay.subtract(1, "month").startOf("day");
      default:
        return fullDay.subtract(1, "month").startOf("day");
    }
  }

  @action
  setCustomDateRange(startDate, endDate) {
    this.startDate = startDate;
    this.endDate = endDate;
    this.filters.startDate = this.startDate;
    this.filters.endDate = this.endDate;
  }

  @action
  setPeriod(period) {
    this.set("period", period);
    this.startDate = this.calculateStartDate();
    this.filters.startDate = this.startDate;
    this.filters.endDate = this.endDate;
  }

  @action
  openCustomDateRangeModal() {
    this.modal.show(CustomDateRangeModal, {
      model: {
        startDate: this.startDate,
        endDate: this.endDate,
        setCustomDateRange: this.setCustomDateRange,
      },
    });
  }
}
