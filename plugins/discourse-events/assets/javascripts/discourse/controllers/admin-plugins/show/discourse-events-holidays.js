import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsShowDiscourseCalendarHolidaysController extends Controller {
  @tracked selectedRegion = null;
  @tracked loading = false;
  @tracked holidays = null;

  @action
  async getHolidays(regionCode) {
    if (this.loading) {
      return;
    }

    this.selectedRegion = regionCode;
    this.loading = true;

    try {
      const response = await ajax(
        `/admin/discourse-calendar/holiday-regions/${regionCode}/holidays`
      );

      this.holidays = response.holidays;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
}
