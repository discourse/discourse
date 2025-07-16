import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import roundTime from "../lib/round-time";

export default createWidget("discourse-group-timezones-time-traveler", {
  tagName: "div.group-timezones-time-traveler",

  transform(attrs) {
    let date = moment().add(attrs.localTimeOffset, "minutes");

    if (attrs.localTimeOffset) {
      date = roundTime(date);
    }

    return {
      localTimeWithOffset: date.format("HH:mm"),
    };
  },

  template: hbs`
    <span class="time">
      {{transformed.localTimeWithOffset}}
    </span>
    <span class="discourse-group-timezones-slider-wrapper">
      {{attach
        widget="discourse-group-timezones-slider"
      }}
    </span>
    {{attach
      widget="discourse-group-timezones-reset"
      attrs=(hash
        id=attrs.id
        localTimeOffset=attrs.localTimeOffset
      )
    }}
  `,
});
