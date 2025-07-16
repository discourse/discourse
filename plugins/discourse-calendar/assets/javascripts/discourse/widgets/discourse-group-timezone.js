import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezone", {
  tagName: "div.group-timezone",

  buildClasses(attrs) {
    const classes = [];

    if (attrs.groupedTimezone.closeToWorkingHours) {
      classes.push("close-to-working-hours");
    }

    if (attrs.groupedTimezone.inWorkingHours) {
      classes.push("in-working-hours");
    }

    return classes.join(" ");
  },

  transform(attrs) {
    return {
      formatedTime: attrs.groupedTimezone.nowWithOffset.format("LT"),
    };
  },

  template: hbs`
    <div class="info">
      <span class="time">
        {{transformed.formatedTime}}
      </span>
      <span class="offset" title="UTC offset">
        {{{attrs.groupedTimezone.utcOffset}}}
      </span>
    </div>
    <ul class="group-timezones-members">
      {{#each attrs.groupedTimezone.members as |member|}}
        {{attach
          widget="discourse-group-timezones-member"
          attrs=(hash
            usersOnHoliday=attrs.usersOnHoliday
            member=member
          )
        }}
      {{/each}}
    </ul>
  `,
});
