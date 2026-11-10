import { concat } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

const UserNotificationScheduleDay = <template>
  {{#let (i18n (concat "user.notification_schedule." @day)) as |dayLabel|}}
    <tr class="day {{dayLabel}}">
      <td class="day-label">{{dayLabel}}</td>
      <td class="starts-at">
        <ComboBox
          @content={{@startTimeOptions}}
          @onChange={{@onChangeStartTime}}
          @value={{@startTimeValue}}
          @valueProperty="value"
        />
      </td>
      {{#if @endTimeOptions}}
        <td class="to">{{i18n "user.notification_schedule.to"}}</td>
        <td class="ends-at">
          <ComboBox
            @content={{@endTimeOptions}}
            @onChange={{@onChangeEndTime}}
            @value={{@endTimeValue}}
            @valueProperty="value"
          />
        </td>
      {{/if}}
    </tr>
  {{/let}}
</template>;

export default UserNotificationScheduleDay;
