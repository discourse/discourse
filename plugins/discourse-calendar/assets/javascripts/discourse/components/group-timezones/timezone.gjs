import Component from "@glimmer/component";
import UserAvatar from "discourse/components/user-avatar";
import concatClass from "discourse/helpers/concat-class";

export default class GroupTimezone extends Component {
  get formattedTime() {
    return this.args.groupedTimezone.nowWithOffset.format("LT");
  }

  <template>
    <div
      class={{concatClass
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
            class={{concatClass
              "group-timezones-member"
              (if member.on_holiday "on-holiday" "not-on-holiday")
            }}
          >
            <UserAvatar
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
