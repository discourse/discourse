import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import ComboBoxComponent from "select-kit/components/combo-box";

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
    this.userTimezone = this.currentUser.user_option.timezone;
  },

  modifyComponentForRow() {
    return "future-date-input-selector/future-date-input-selector-row";
  },

  actions: {
    onChange(value) {
      if (value !== "custom" && !isEmpty(value)) {
        const { time } = this.content.find((x) => x.id === value);
        if (time) {
          this.onChangeInput?.(time.locale("en").format(FORMAT));
        }
      }

      this.onChange?.(value);
    },
  },
});
