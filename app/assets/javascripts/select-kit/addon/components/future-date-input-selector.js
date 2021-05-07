import ComboBoxComponent from "select-kit/components/combo-box";
import I18n from "I18n";
import { equal } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import {
  TIME_SHORTCUT_TYPES,
  additionalTimeframeOptions,
  defaultShortcutOptions,
  specialShortcutOptions,
} from "discourse/lib/time-shortcut";
import discourseComputed, { on } from "discourse-common/utils/decorators";

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

  @on("init")
  _init() {
    this.setProperties({
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
    });
  },

  modifyComponentForRow() {
    return "future-date-input-selector/future-date-input-selector-row";
  },

  @discourseComputed("defaultOptions", "customOptions")
  content(defaultOptions, customOptions) {
    let options = defaultOptions;
    this._setupDynamicOptions(options);

    if (customOptions) {
      options = options.concat(customOptions);
    }

    options.sort(this._compareOptions);

    if (this.includeDateTime) {
      const customDateTime = specialShortcutOptions().findBy(
        "id",
        TIME_SHORTCUT_TYPES.CUSTOM
      );
      options.push(customDateTime);
    }

    return options
      .filter((option) => !option.hidden)
      .map((option) => {
        return {
          id: option.id,
          name: I18n.t(option.label),
          time: option.time,
          datetime: this._timeFormatted(option),
          icons: [option.icon],
        };
      });
  },

  @discourseComputed("userTimezone")
  defaultOptions(userTimezone) {
    const options = defaultShortcutOptions(userTimezone);
    options.push(additionalTimeframeOptions(userTimezone).thisWeekend());
    options.findBy(
      "id",
      TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK
    ).hidden = true;
    return options;
  },

  _compareOptions(a, b) {
    if (a.time < b.time) {
      return -1;
    }
    if (a.time > b.time) {
      return 1;
    }
    return 0;
  },

  _setupDynamicOptions(options) {
    const now = moment();
    const showLaterToday = 24 - now.hour() > 6;
    const showLaterThisWeek = !showLaterToday && now.day() < 4;
    const showThisWeekend = now.day() < 5 && this.includeWeekend;
    const showNextWeek = now.day() !== 0;
    const showNextMonth = now.date() !== moment().endOf("month").date();

    options.findBy(
      "id",
      TIME_SHORTCUT_TYPES.LATER_TODAY
    ).hidden = !showLaterToday;

    options.findBy(
      "id",
      TIME_SHORTCUT_TYPES.LATER_THIS_WEEK
    ).hidden = !showLaterThisWeek;

    options.findBy(
      "id",
      TIME_SHORTCUT_TYPES.THIS_WEEKEND
    ).hidden = !showThisWeekend;

    options.findBy("id", TIME_SHORTCUT_TYPES.NEXT_WEEK).hidden = !showNextWeek;

    options.findBy(
      "id",
      TIME_SHORTCUT_TYPES.NEXT_MONTH
    ).hidden = !showNextMonth;
  },

  _timeFormatted(option) {
    if (option.timeFormatted) {
      return option.timeFormatted;
    }

    if (option.time && option.timeFormatKey) {
      return option.time.format(I18n.t(option.timeFormatKey));
    } else {
      return null;
    }
  },

  actions: {
    onChange(value) {
      if (value !== TIME_SHORTCUT_TYPES.CUSTOM && !isEmpty(value)) {
        const time = this.content.findBy("id", value).time;
        if (time) {
          this.attrs.onChangeInput &&
            this.attrs.onChangeInput(time.locale("en").format(FORMAT));
        }
      }

      this.attrs.onChange && this.attrs.onChange(value);
    },
  },
});
