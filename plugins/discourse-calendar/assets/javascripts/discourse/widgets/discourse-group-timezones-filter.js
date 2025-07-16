import { throttle } from "@ember/runloop";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export default createWidget("discourse-group-timezones-filter", {
  tagName: "input.group-timezones-filter",

  input(event) {
    this.changeFilterThrottler(event.target.value);
  },

  changeFilterThrottler(filter) {
    throttle(
      this,
      function () {
        this.sendWidgetAction("onChangeFilter", filter);
      },
      100
    );
  },

  buildAttributes() {
    return {
      type: "text",
      placeholder: i18n("group_timezones.search"),
    };
  },
});
