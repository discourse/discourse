import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsCalendarController extends Controller {
  selectedRegion = null;
  loading = false;

  @action
  async getHolidays(region_code) {
    if (this.loading) {
      return;
    }

    this.set("selectedRegion", region_code);
    this.set("loading", true);

    return ajax(
      `/admin/discourse-calendar/holiday-regions/${region_code}/holidays`
    )
      .then((response) => {
        this.model.set("holidays", response.holidays);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("loading", false));
  }
}
