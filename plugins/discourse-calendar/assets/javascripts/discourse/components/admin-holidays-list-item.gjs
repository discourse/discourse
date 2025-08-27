/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { classNameBindings, tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

@tagName("tr")
@classNameBindings("isHolidayDisabled:disabled")
export default class AdminHolidaysListItem extends Component {
  loading = false;
  isHolidayDisabled = false;

  @action
  async disableHoliday() {
    if (this.loading) {
      return;
    }

    this.set("loading", true);

    try {
      await ajax({
        url: `/admin/discourse-calendar/holidays/disable`,
        type: "POST",
        data: {
          disabled_holiday: {
            holiday_name: this.holiday.name,
            region_code: this.region_code,
          },
        },
      });
      this.set("isHolidayDisabled", true);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.set("loading", false);
    }
  }

  @action
  async enableHoliday() {
    if (this.loading) {
      return;
    }

    this.set("loading", true);

    try {
      await ajax({
        url: `/admin/discourse-calendar/holidays/enable`,
        type: "DELETE",
        data: {
          disabled_holiday: {
            holiday_name: this.holiday.name,
            region_code: this.region_code,
          },
        },
      });
      this.set("isHolidayDisabled", false);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.set("loading", false);
    }
  }

  <template>
    <td>{{this.holiday.date}}</td>
    <td>{{this.holiday.name}}</td>
    <td>
      {{#if this.isHolidayDisabled}}
        <DButton
          @action={{this.enableHoliday}}
          @label="discourse_calendar.enable_holiday"
        />
      {{else}}
        <DButton
          @action={{this.disableHoliday}}
          @label="discourse_calendar.disable_holiday"
        />
      {{/if}}
    </td>
  </template>
}
