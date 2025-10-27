import Controller from "@ember/controller";
import { action } from "@ember/object";
import computed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class CakedayAnniversariesTodayController extends Controller {
  @computed
  title() {
    return i18n("anniversaries.today.title", {
      date: moment().format(i18n("dates.full_no_year_no_time")),
    });
  }

  @action
  loadMore() {
    this.get("model").loadMore();
  }
}
