import { throttle } from "@ember/runloop";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-group-timezones-slider", {
  tagName: "input.group-timezones-slider",

  input(event) {
    this._handleSliderEvent(event);
  },

  change(event) {
    this._handleSliderEvent(event);
  },

  changeOffsetThrottler(offset) {
    throttle(
      this,
      function () {
        this.sendWidgetAction("onChangeCurrentUserTimeOffset", offset);
      },
      75
    );
  },

  buildAttributes() {
    return {
      step: 1,
      value: 0,
      min: -48,
      max: 48,
      type: "range",
    };
  },

  _handleSliderEvent(event) {
    const value = parseInt(event.target.value, 10);
    const offset = value * 15;
    this.changeOffsetThrottler(offset);
  },
});
