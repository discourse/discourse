import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class CakedayBirthdaysUpcomingController extends Controller {
  @computed
  get title() {
    const dateFormat = i18n("dates.full_no_year_no_time");

    return i18n("birthdays.upcoming.title", {
      start_date: moment().add(2, "days").format(dateFormat),
      end_date: moment().add(2, "days").add(1, "week").format(dateFormat),
    });
  }

  @action
  loadMore() {
    this.get("model").loadMore();
  }
}
