import ComboBoxComponent from "select-kit/components/combo-box";
import DatetimeMixin from "select-kit/components/future-date-input-selector/mixin";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import buildTimeframes from "discourse/lib/timeframes-builder";
import I18n from "I18n";

export const FORMAT = "YYYY-MM-DD HH:mmZ";

export default ComboBoxComponent.extend(DatetimeMixin, {
  pluginApiIdentifiers: ["future-date-input-selector"],
  classNames: ["future-date-input-selector"],
  isCustom: equal("value", "pick_date_and_time"),

  selectKitOptions: {
    autoInsertNoneItem: false,
    headerComponent:
      "future-date-input-selector/future-date-input-selector-header",
  },

  modifyComponentForRow() {
    return "future-date-input-selector/future-date-input-selector-row";
  },

  content: computed("statusType", function () {
    const now = moment();
    const opts = {
      now,
      day: now.day(),
      includeWeekend: this.includeWeekend,
      includeFarFuture: this.includeFarFuture,
      includeDateTime: this.includeDateTime,
      canScheduleNow: this.includeNow || false,
      canScheduleToday: 24 - now.hour() > 6,
    };

    return buildTimeframes(opts).map((tf) => {
      return {
        id: tf.id,
        name: I18n.t(`topic.auto_update_input.${tf.id}`),
        datetime: this._computeDatetimeForValue(tf.id),
        icons: this._computeIconsForValue(tf.id),
      };
    });
  }),

  actions: {
    onChange(value) {
      if (value !== "pick_date_and_time") {
        const { time } = this._updateAt(value);
        if (time && !isEmpty(value)) {
          this.attrs.onChangeInput &&
            this.attrs.onChangeInput(time.locale("en").format(FORMAT));
        }
      }

      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
