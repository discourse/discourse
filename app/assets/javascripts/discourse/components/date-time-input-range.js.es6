import { equal } from "@ember/object/computed";
import Component from "@ember/component";
export default Component.extend({
  classNames: ["d-date-time-input-range"],

  from: null,
  to: null,
  onChangeTo: null,
  onChangeFrom: null,
  currentPanel: "from",
  showFromTime: true,
  showToTime: true,
  error: null,

  fromPanelActive: equal("currentPanel", "from"),
  toPanelActive: equal("currentPanel", "to"),

  _valid(state) {
    if (state.to < state.from) {
      return I18n.t("date_time_picker.errors.to_before_from");
    }

    return true;
  },

  actions: {
    _onChange(options, value) {
      if (this.onChange) {
        const state = {
          from: this.from,
          to: this.to
        };

        const diff = {};
        diff[options.prop] = value;

        const newState = Object.assign(state, diff);

        const validation = this._valid(newState);
        if (validation === true) {
          this.set("error", null);
          this.onChange(newState);
        } else {
          this.set("error", validation);
        }
      }
    },

    onChangePanel(panel) {
      this.set("currentPanel", panel);
    }
  }
});
