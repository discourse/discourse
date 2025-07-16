import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezone-new-day", {
  tagName: "div.group-timezone-new-day",

  template: hbs`
    <span class="before">
      {{d-icon "chevron-left"}}
      {{this.attrs.groupedTimezone.beforeDate}}
    </span>
    <span class="after">
      {{this.attrs.groupedTimezone.afterDate}}
      {{d-icon "chevron-right"}}
    </span>
  `,
});
