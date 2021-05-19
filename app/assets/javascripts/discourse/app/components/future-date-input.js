import { and, empty, equal } from "@ember/object/computed";
import { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import I18n from "I18n";

export default Component.extend({
  selection: null,
  date: null,
  time: null,
  includeDateTime: true,
  isCustom: equal("selection", "custom"),
  displayDateAndTimePicker: and("includeDateTime", "isCustom"),
  displayLabel: null,
  labelClasses: null,

  init() {
    this._super(...arguments);

    if (this.input) {
      const datetime = moment(this.input);
      this.setProperties({
        selection: "custom",
        date: datetime.format("YYYY-MM-DD"),
        time: datetime.format("HH:mm"),
      });
    }
  },

  timeInputDisabled: empty("date"),

  @observes("date", "time")
  _updateInput() {
    if (!this.date) {
      this.set("time", null);
    }

    const time = this.time ? ` ${this.time}` : "";
    const dateTime = moment(`${this.date}${time}`);

    if (dateTime.isValid()) {
      this.attrs.onChangeInput &&
        this.attrs.onChangeInput(dateTime.format(FORMAT));
    } else {
      this.attrs.onChangeInput && this.attrs.onChangeInput(null);
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.label) {
      this.set("displayLabel", I18n.t(this.label));
    }
  },
});
