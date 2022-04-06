import ComboBoxComponent from "select-kit/components/combo-box";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import buildTimeframes from "discourse/lib/timeframes-builder";
import I18n from "I18n";

export const FORMAT = "YYYY-MM-DD HH:mmZ";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["future-date-input-selector"],
  classNames: ["future-date-input-selector"],
  isCustom: equal("value", "custom"),
  userTimezone: null,

  selectKitOptions: {
    autoInsertNoneItem: false,
    headerComponent:
      "future-date-input-selector/future-date-input-selector-header",
  },

  init() {
    this._super(...arguments);
    this.userTimezone = this.currentUser.resolvedTimezone(this.currentUser);
  },

  modifyComponentForRow() {
    return "future-date-input-selector/future-date-input-selector-row";
  },

  content: computed("statusType", function () {
    const opts = {
      includeWeekend: this.includeWeekend,
      includeFarFuture: this.includeFarFuture,
      includeDateTime: this.includeDateTime,
      canScheduleNow: this.includeNow || false,
    };

    return buildTimeframes(this.userTimezone, opts).map((tf) => {
      return {
        id: tf.id,
        name: I18n.t(tf.label),
        time: tf.time,
        timeFormatted: tf.timeFormatted,
      };
    });
  }),

  actions: {
    onChange(value) {
      if (value !== "custom" && !isEmpty(value)) {
        const { time } = this.content.find((x) => x.id === value);
        if (time) {
          this.attrs.onChangeInput &&
            this.attrs.onChangeInput(time.locale("en").format(FORMAT));
        }
      }

      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
