import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export default createWidget("discourse-group-timezones-header", {
  tagName: "div.group-timezones-header",

  transform(attrs) {
    return {
      title: i18n("group_timezones.group_availability", {
        group: attrs.group,
      }),
    };
  },

  template: hbs`
    {{attach
      widget="discourse-group-timezones-time-traveler"
      attrs=(hash
        id=attrs.id
        localTimeOffset=attrs.localTimeOffset
      )
    }}
    <span class="title">
      {{transformed.title}}
    </span>
    {{attach widget="discourse-group-timezones-filter"}}
  `,
});
