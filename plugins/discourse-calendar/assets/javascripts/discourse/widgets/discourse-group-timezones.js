import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import roundTime from "../lib/round-time";

export default createWidget("discourse-group-timezones", {
  tagName: "div.group-timezones",

  buildKey: (attrs) => `group-timezones-${attrs.id}`,

  buildClasses(attrs) {
    return attrs.size;
  },

  buildAttributes(attrs) {
    return {
      id: attrs.id,
    };
  },

  defaultState() {
    return {
      localTimeOffset: 0,
    };
  },

  onChangeCurrentUserTimeOffset(offset) {
    this.state.localTimeOffset = offset;
  },

  transform(attrs, state) {
    const members = attrs.members || [];
    let groupedTimezones = [];

    members.filterBy("timezone").forEach((member) => {
      if (this._shouldAddMemberToGroup(this.state.filter, member)) {
        const timezone = member.timezone;
        const identifier = parseInt(moment.tz(timezone).format("YYYYMDHm"), 10);
        let groupedTimezone = groupedTimezones.findBy("identifier", identifier);

        if (groupedTimezone) {
          groupedTimezone.members.push(member);
        } else {
          const now = this._roundMoment(moment.tz(timezone));
          const workingDays = this._workingDays();
          const offset = moment.tz(moment.utc(), timezone).utcOffset();

          groupedTimezone = {
            identifier,
            offset,
            type: "discourse-group-timezone",
            nowWithOffset: now.add(state.localTimeOffset, "minutes"),
            closeToWorkingHours: this._closeToWorkingHours(now, workingDays),
            inWorkingHours: this._inWorkingHours(now, workingDays),
            utcOffset: this._utcOffset(offset),
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

    return { groupedTimezones };
  },

  onChangeFilter(filter) {
    this.state.filter = filter && filter.length ? filter : null;
  },

  template: hbs`
    {{attach
      widget="discourse-group-timezones-header"
      attrs=(hash
        id=attrs.id
        group=attrs.group
        localTimeOffset=state.localTimeOffset
      )
    }}
    <div class="group-timezones-body">
      {{#each transformed.groupedTimezones as |groupedTimezone|}}
        {{attach
          widget=groupedTimezone.type
          attrs=(hash
            usersOnHoliday=attrs.usersOnHoliday
            groupedTimezone=groupedTimezone
          )
        }}
      {{/each}}
    </div>
  `,

  _shouldAddMemberToGroup(filter, member) {
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
  },

  _roundMoment(date) {
    if (this.state.localTimeOffset) {
      date = roundTime(date);
    }

    return date;
  },

  _closeToWorkingHours(moment, workingDays) {
    const hours = moment.hours();
    const startHour = this.siteSettings.working_day_start_hour;
    const endHour = this.siteSettings.working_day_end_hour;
    const extension = this.siteSettings.close_to_working_day_hours_extension;

    return (
      ((hours >= Math.max(startHour - extension, 0) && hours <= startHour) ||
        (hours <= Math.min(endHour + extension, 23) && hours >= endHour)) &&
      workingDays.includes(moment.isoWeekday())
    );
  },

  _inWorkingHours(moment, workingDays) {
    const hours = moment.hours();
    return (
      hours > this.siteSettings.working_day_start_hour &&
      hours < this.siteSettings.working_day_end_hour &&
      workingDays.includes(moment.isoWeekday())
    );
  },

  _utcOffset(offset) {
    const sign = Math.sign(offset) === 1 ? "+" : "-";
    offset = Math.abs(offset);
    let hours = Math.floor(offset / 60).toString();
    hours = hours.length === 1 ? `0${hours}` : hours;
    let minutes = (offset % 60).toString();
    minutes = minutes.length === 1 ? `:${minutes}0` : `:${minutes}`;
    return `${sign}${hours.replace(/^0(\d)/, "$1")}${minutes.replace(
      /:00$/,
      ""
    )}`.replace(/-0/, "&nbsp;");
  },

  _workingDays() {
    const enMoment = moment().locale("en");
    const getIsoWeekday = (day) =>
      enMoment.localeData()._weekdays.indexOf(day) || 7;
    return this.siteSettings.working_days
      .split("|")
      .filter(Boolean)
      .map((x) => getIsoWeekday(x));
  },
});
