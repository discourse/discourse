/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

@tagName("")
export default class UserNotificationScheduleDay extends Component {
  <template>
    <tr class="day {{this.dayLabel}}">
      <td class="day-label">{{this.dayLabel}}</td>
      <td class="starts-at">
        <ComboBox
          @content={{this.startTimeOptions}}
          @onChange={{this.onChangeStartTime}}
          @value={{this.startTimeValue}}
          @valueProperty="value"
        />
      </td>
      {{#if this.endTimeOptions}}
        <td class="to">{{i18n "user.notification_schedule.to"}}</td>
        <td class="ends-at">
          <ComboBox
            @content={{this.endTimeOptions}}
            @onChange={{this.onChangeEndTime}}
            @value={{this.endTimeValue}}
            @valueProperty="value"
          />
        </td>
      {{/if}}
    </tr>
  </template>

  @computed("day")
  get dayLabel() {
    return i18n(`user.notification_schedule.${this.day}`);
  }
}
