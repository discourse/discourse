import Controller from "@ember/controller";
import { action } from "@ember/object";
import computed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class CakedayAnniversariesUpcomingController extends Controller {
  @computed
  title() {
    const dateFormat = i18n("dates.full_no_year_no_time");

    return i18n("anniversaries.upcoming.title", {
      start_date: moment().add(2, "days").format(dateFormat),
      end_date: moment().add(2, "days").add(1, "week").format(dateFormat),
    });
  }

  @action
  loadMore() {
    this.get("model").loadMore();
  }
}
