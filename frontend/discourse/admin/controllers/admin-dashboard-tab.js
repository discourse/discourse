import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CustomDateRangeModal from "../components/modal/custom-date-range";

export default class AdminDashboardTabController extends Controller {
  @service modal;

  queryParams = ["period", "start_date", "end_date"];
  period = "monthly";
  start_date = null;
  end_date = null;

  get startDate() {
    if (this.start_date) {
      return moment(this.start_date).locale("en").utc().startOf("day");
    }
    return this.#calculateStartDate();
  }

  get endDate() {
    if (this.end_date) {
      return moment(this.end_date).locale("en").utc().endOf("day");
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
    this.setProperties({
      period: "custom",
      start_date: moment(startDate).format("YYYY-MM-DD"),
      end_date: moment(endDate).format("YYYY-MM-DD"),
    });
  }

  @action
  setPeriod(period) {
    this.setProperties({ period, start_date: null, end_date: null });
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
