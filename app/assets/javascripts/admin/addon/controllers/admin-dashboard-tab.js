import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import CustomDateRangeModal from "../components/modal/custom-date-range";

export default class AdminDashboardTabController extends Controller {
  @service modal;

  queryParams = ["period"];
  period = "monthly";

  endDate = moment().locale("en").utc().endOf("day");
  _startDate;

  @computed("_startDate", "period")
  get startDate() {
    if (this._startDate) {
      return this._startDate;
    }

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
  setCustomDateRange(_startDate, endDate) {
    this.setProperties({ _startDate, endDate });
  }

  @action
  setPeriod(period) {
    this.setProperties({ period, _startDate: null });
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
