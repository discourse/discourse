import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import roundTime from "../../lib/round-time";
import NewDay from "./new-day";
import TimeTraveller from "./time-traveller";
import Timezone from "./timezone";

const nbsp = "\xa0";

export default class GroupTimezones extends Component {
  @service siteSettings;

  @tracked filter = "";
  @tracked localTimeOffset = 0;

  get groupedTimezones() {
    let groupedTimezones = [];

    this.args.members.filterBy("timezone").forEach((member) => {
      if (this.#shouldAddMemberToGroup(this.filter, member)) {
        const timezone = member.timezone;
        const identifier = parseInt(moment.tz(timezone).format("YYYYMDHm"), 10);
        let groupedTimezone = groupedTimezones.findBy("identifier", identifier);

        if (groupedTimezone) {
          groupedTimezone.members.push(member);
        } else {
          const now = this.#roundMoment(moment.tz(timezone));
          const workingDays = this.#workingDays();
          const offset = moment.tz(moment.utc(), timezone).utcOffset();

          groupedTimezone = {
            identifier,
            offset,
            type: "discourse-group-timezone",
            nowWithOffset: now.add(this.localTimeOffset, "minutes"),
            closeToWorkingHours: this.#closeToWorkingHours(now, workingDays),
            inWorkingHours: this.#inWorkingHours(now, workingDays),
            utcOffset: this.#utcOffset(offset),
            members: [member],
          };
          groupedTimezones.push(groupedTimezone);
        }
      }
    });

    groupedTimezones = groupedTimezones
      .sortBy("offset")
      .filter((g) => g.members.length);

    let newDayIndex;
    groupedTimezones.forEach((groupedTimezone, index) => {
      if (index > 0) {
        if (
          groupedTimezones[index - 1].nowWithOffset.format("dddd") !==
          groupedTimezone.nowWithOffset.format("dddd")
        ) {
          newDayIndex = index;
        }
      }
    });

    if (newDayIndex) {
      groupedTimezones.splice(newDayIndex, 0, {
        type: "discourse-group-timezone-new-day",
        beforeDate:
          groupedTimezones[newDayIndex - 1].nowWithOffset.format("dddd"),
        afterDate: groupedTimezones[newDayIndex].nowWithOffset.format("dddd"),
      });
    }

    return groupedTimezones;
  }

  #shouldAddMemberToGroup(filter, member) {
    if (filter) {
      filter = filter.toLowerCase();
      if (
        member.username.toLowerCase().indexOf(filter) > -1 ||
        (member.name && member.name.toLowerCase().indexOf(filter) > -1)
      ) {
        return true;
      }
    } else {
      return true;
    }

    return false;
  }

  #roundMoment(date) {
    if (this.localTimeOffset) {
      date = roundTime(date);
    }

    return date;
  }

  #closeToWorkingHours(moment, workingDays) {
    const hours = moment.hours();
    const startHour = this.siteSettings.working_day_start_hour;
    const endHour = this.siteSettings.working_day_end_hour;
    const extension = this.siteSettings.close_to_working_day_hours_extension;

    return (
      ((hours >= Math.max(startHour - extension, 0) && hours <= startHour) ||
        (hours <= Math.min(endHour + extension, 23) && hours >= endHour)) &&
      workingDays.includes(moment.isoWeekday())
    );
  }

  #inWorkingHours(moment, workingDays) {
    const hours = moment.hours();
    return (
      hours > this.siteSettings.working_day_start_hour &&
      hours < this.siteSettings.working_day_end_hour &&
      workingDays.includes(moment.isoWeekday())
    );
  }

  #utcOffset(offset) {
    const sign = Math.sign(offset) === 1 ? "+" : "-";
    offset = Math.abs(offset);
    let hours = Math.floor(offset / 60).toString();
    hours = hours.length === 1 ? `0${hours}` : hours;
    let minutes = (offset % 60).toString();
    minutes = minutes.length === 1 ? `:${minutes}0` : `:${minutes}`;
    return `${sign}${hours.replace(/^0(\d)/, "$1")}${minutes.replace(
      /:00$/,
      ""
    )}`.replace(/-0/, nbsp);
  }

  #workingDays() {
    const enMoment = moment().locale("en");
    const getIsoWeekday = (day) =>
      enMoment.localeData()._weekdays.indexOf(day) || 7;
    return this.siteSettings.working_days
      .split("|")
      .filter(Boolean)
      .map((x) => getIsoWeekday(x));
  }

  @action
  handleFilterChange(event) {
    this.filter = event.target.value;
  }

  <template>
    <div class="group-timezones-header">
      <TimeTraveller
        @localTimeOffset={{this.localTimeOffset}}
        @setOffset={{fn (mut this.localTimeOffset)}}
      />
      <span class="title">
        {{i18n "group_timezones.group_availability" group=@group}}
      </span>
      <input
        type="text"
        placeholder={{i18n "group_timezones.search"}}
        class="group-timezones-filter"
        {{on "input" this.handleFilterChange}}
      />
    </div>
    <div class="group-timezones-body">
      {{#each this.groupedTimezones key="identifier" as |groupedTimezone|}}
        {{#if (eq groupedTimezone.type "discourse-group-timezone-new-day")}}
          <NewDay
            @beforeDate={{groupedTimezone.beforeDate}}
            @afterDate={{groupedTimezone.afterDate}}
          />
        {{else}}
          <Timezone @groupedTimezone={{groupedTimezone}} />
        {{/if}}
      {{/each}}
    </div>
  </template>
}
