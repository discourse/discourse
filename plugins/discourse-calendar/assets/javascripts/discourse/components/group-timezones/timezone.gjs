import Component from "@glimmer/component";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class GroupTimezone extends Component {
  get formattedTime() {
    return this.args.groupedTimezone.nowWithOffset.format("LT");
  }

  <template>
    <div
      class={{dConcatClass
        "group-timezone"
        (if @groupedTimezone.closeToWorkingHours "close-to-working-hours")
        (if @groupedTimezone.inWorkingHours "in-working-hours")
      }}
    >
      <div class="info">
        <span class="time">
          {{this.formattedTime}}
        </span>
        <span class="offset" title="UTC offset">
          {{@groupedTimezone.utcOffset}}
        </span>
      </div>
      <ul class="group-timezones-members">
        {{#each @groupedTimezone.members key="username" as |member|}}
          <li
            class={{dConcatClass
              "group-timezones-member"
              (if member.on_holiday "on-holiday" "not-on-holiday")
            }}
          >
            <DUserAvatar
              @user={{member}}
              @size="small"
              class="group-timezones-member-avatar"
            />
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
