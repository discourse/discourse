import Component from "@ember/component";
import { action } from "@ember/object";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

@tagName("tr")
@classNameBindings("isHolidayDisabled:disabled")
export default class AdminHolidaysListItem extends Component {
  loading = false;
  isHolidayDisabled = false;

  @action
  disableHoliday(holiday, region_code) {
    if (this.loading) {
      return;
    }

    this.set("loading", true);

    return ajax({
      url: `/admin/discourse-calendar/holidays/disable`,
      type: "POST",
      data: { disabled_holiday: { holiday_name: holiday.name, region_code } },
    })
      .then(() => this.set("isHolidayDisabled", true))
      .catch(popupAjaxError)
      .finally(() => this.set("loading", false));
  }

  @action
  enableHoliday(holiday, region_code) {
    if (this.loading) {
      return;
    }

    this.set("loading", true);

    return ajax({
      url: `/admin/discourse-calendar/holidays/enable`,
      type: "DELETE",
      data: { disabled_holiday: { holiday_name: holiday.name, region_code } },
    })
      .then(() => this.set("isHolidayDisabled", false))
      .catch(popupAjaxError)
      .finally(() => this.set("loading", false));
  }
}
