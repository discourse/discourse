import { oneWay, or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import { isNumeric } from "discourse/lib/utilities";

export default Component.extend({
  classNames: ["d-time-input"],
  hours: null,
  minutes: null,
  _hours: oneWay("hours"),
  _minutes: oneWay("minutes"),
  isSafari: oneWay("capabilities.isSafari"),
  isMobile: oneWay("site.mobileView"),
  nativePicker: or("isSafari", "isMobile"),

  actions: {
    onInput(options, event) {
      event.preventDefault();

      if (this.onChange) {
        let value = event.target.value;

        if (!isNumeric(value)) {
          value = 0;
        } else {
          value = parseInt(value, 10);
        }

        if (options.prop === "hours") {
          value = Math.max(0, Math.min(value, 23))
            .toString()
            .padStart(2, "0");
          this._processHoursChange(value);
        } else {
          value = Math.max(0, Math.min(value, 59))
            .toString()
            .padStart(2, "0");
          this._processMinutesChange(value);
        }

        schedule("afterRender", () => (event.target.value = value));
      }
    },

    onFocusIn(value, event) {
      if (value && event.target) {
        event.target.select();
      }
    },

    onChangeTime(event) {
      const time = event.target.value;

      if (time && this.onChange) {
        this.onChange({
          hours: time.split(":")[0],
          minutes: time.split(":")[1]
        });
      }
    }
  },

  _processHoursChange(hours) {
    this.onChange({
      hours,
      minutes: this._minutes || "00"
    });
  },

  _processMinutesChange(minutes) {
    this.onChange({
      hours: this._hours || "00",
      minutes
    });
  }
});
