import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminHolidaysListItem extends Component {
  @tracked loading = false;
  @tracked isHolidayDisabled = this.args.isHolidayDisabled || false;

  @action
  async toggleEnableHoliday() {
    if (this.loading) {
      return;
    }

    let url, type;

    if (this.isHolidayDisabled) {
      url = `/admin/discourse-calendar/holidays/enable`;
      type = "DELETE";
    } else {
      url = `/admin/discourse-calendar/holidays/disable`;
      type = "POST";
    }

    this.loading = true;

    try {
      await ajax({
        url,
        type,
        data: {
          disabled_holiday: {
            holiday_name: this.args.holiday.name,
            region_code: this.args.regionCode,
          },
        },
      });
      this.isHolidayDisabled = !this.isHolidayDisabled;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <tr class="d-table__row {{if this.isHolidayDisabled '--disabled'}}">
      <td class="d-table__cell --detail">{{@holiday.date}}</td>
      <td class="d-table__cell --detail">{{@holiday.name}}</td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          <DButton
            @action={{this.toggleEnableHoliday}}
            @label={{if
              this.isHolidayDisabled
              "discourse_calendar.enable_holiday"
              "discourse_calendar.disable_holiday"
            }}
            @isLoading={{this.loading}}
            class="btn-default btn-small"
          />
        </div>
      </td>
    </tr>
  </template>
}
