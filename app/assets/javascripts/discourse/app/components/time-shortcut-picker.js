import {
  START_OF_DAY_HOUR,
  laterToday,
  now,
  parseCustomDatetime,
} from "discourse/lib/timeUtils";
import {
  TIME_SHORTCUT_TYPES,
  defaultShortcutOptions,
} from "discourse/lib/timeShortcut";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  userTimezone: null,

  onTimeSelected: null,

  selectedShortcut: null,
  selectedTime: null,
  selectedDate: null,
  selectedDatetime: null,
  prefilledDatetime: null,

  additionalOptionsToShow: [],
  hiddenOptions: [],
  customOptions: [],

  lastCustomDate: null,
  lastCustomTime: null,
  parsedLastCustomDatetime: null,
  customDate: null,
  customTime: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      customTime: this._defaultCustomReminderTime(),
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
    });

    if (this.prefilledDatetime) {
      let parsedDatetime = parseCustomDatetime(
        this.prefilledDatetime,
        null,
        this.userTimezone
      );

      if (parsedDatetime.isSame(laterToday())) {
        return this.set("selectedShortcut", TIME_SHORTCUT_TYPES.LATER_TODAY);
      }

      this.setProperties({
        customDate: parsedDatetime.format("YYYY-MM-DD"),
        customTime: parsedDatetime.format("HH:mm"),
        selectedShortcut: TIME_SHORTCUT_TYPES.CUSTOM,
      });
    }

    this._loadLastUsedCustomDatetime();
  },

  @discourseComputed("selectedShortcut")
  customDatetimeSelected(selectedShortcut) {
    return selectedShortcut === TIME_SHORTCUT_TYPES.CUSTOM;
  },

  _defaultCustomReminderTime() {
    return `0${START_OF_DAY_HOUR}:00`;
  },

  @observes("customDate", "customTime")
  customDatetimeChanged() {
    this.selectShortcut(TIME_SHORTCUT_TYPES.CUSTOM);
  },

  _loadLastUsedCustomDatetime() {
    let lastTime = localStorage.lastCustomTime;
    let lastDate = localStorage.lastCustomDate;

    if (lastTime && lastDate) {
      let parsed = parseCustomDatetime(lastDate, lastTime, this.userTimezone);

      if (parsed < now(this.userTimezone)) {
        return;
      }

      this.setProperties({
        lastCustomDate: lastDate,
        lastCustomTime: lastTime,
        parsedLastCustomDatetime: parsed,
      });
    }
  },

  @action
  selectShortcut(type) {
    if (
      this.options
        .filter((opt) => opt.hidden)
        .map((opt) => opt.id)
        .includes(type)
    ) {
      return;
    }

    let dateTime = null;
    if (type === TIME_SHORTCUT_TYPES.CUSTOM) {
      this.set(
        "customTime",
        this.customTime || this._defaultCustomReminderTime()
      );
      const customDatetime = parseCustomDatetime(
        this.customDate,
        this.customTime,
        this.userTimezone
      );

      if (customDatetime.isValid()) {
        dateTime = customDatetime;

        localStorage.lastCustomTime = this.customTime;
        localStorage.lastCustomDate = this.customDate;
      }
    } else {
      dateTime = this.options.find((opt) => opt.id === type).time;
    }

    this.setProperties({
      selectedShortcut: type,
      selectedDatetime: dateTime,
    });

    if (this.onTimeSelected) {
      this.onTimeSelected(type, dateTime);
    }
  },

  @discourseComputed(
    "additionalOptionsToShow",
    "hiddenOptions",
    "customOptions",
    "userTimezone"
  )
  options(additionalOptionsToShow, hiddenOptions, customOptions, userTimezone) {
    let options = defaultShortcutOptions(userTimezone);

    if (additionalOptionsToShow.length > 0) {
      options.forEach((opt) => {
        if (additionalOptionsToShow.includes(opt.id)) {
          opt.hidden = false;
        }
      });
    }

    if (hiddenOptions.length > 0) {
      options.forEach((opt) => {
        if (hiddenOptions.includes(opt.id)) {
          opt.hidden = true;
        }
      });
    }

    let customOptionIndex = options.findIndex(
      (opt) => opt.id === TIME_SHORTCUT_TYPES.CUSTOM
    );

    options.splice(customOptionIndex, 0, ...customOptions);

    return options;
  },
});
