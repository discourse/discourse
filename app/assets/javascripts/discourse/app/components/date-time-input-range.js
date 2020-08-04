import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  classNames: ["d-date-time-input-range"],
  from: null,
  to: null,
  onChangeTo: null,
  onChangeFrom: null,
  toTimeFirst: false,
  showToTime: true,
  showFromTime: true,
  clearable: false,

  @action
  onChangeRanges(options, value) {
    if (this.onChange) {
      const state = {
        from: this.from,
        to: this.to
      };

      const diff = {};

      if (options.prop === "from") {
        if (value && value.isAfter(this.to)) {
          diff[options.prop] = value;
          diff["to"] = value.clone().add(1, "hour");
        } else {
          diff[options.prop] = value;
        }
      }

      if (options.prop === "to") {
        if (value && value.isBefore(this.from)) {
          diff[options.prop] = this.from.clone().add(1, "hour");
        } else {
          diff[options.prop] = value;
        }
      }

      const newState = Object.assign({}, state, diff);
      this.onChange(newState);
    }
  }
});
