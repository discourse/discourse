import {
  LATER_TODAY_CUTOFF_HOUR,
  MOMENT_FRIDAY,
  MOMENT_THURSDAY,
  START_OF_DAY_HOUR,
  laterToday,
  now,
  parseCustomDatetime,
} from "discourse/lib/time-utils";
import {
  TIME_SHORTCUT_TYPES,
  defaultShortcutOptions,
  specialShortcutOptions,
} from "discourse/lib/time-shortcut";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";

import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";
import { and, equal } from "@ember/object/computed";

const BINDINGS = {
  "l t": {
    handler: "selectShortcut",
    args: [TIME_SHORTCUT_TYPES.LATER_TODAY],
  },
  "l w": {
    handler: "selectShortcut",
    args: [TIME_SHORTCUT_TYPES.LATER_THIS_WEEK],
  },
  "n d": {
    handler: "selectShortcut",
    args: [TIME_SHORTCUT_TYPES.TOMORROW],
  },
  "n b w": {
    handler: "selectShortcut",
    args: [TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK],
  },
  "n m": {
    handler: "selectShortcut",
    args: [TIME_SHORTCUT_TYPES.NEXT_MONTH],
  },
  "c r": { handler: "selectShortcut", args: [TIME_SHORTCUT_TYPES.CUSTOM] },
  "n r": { handler: "selectShortcut", args: [TIME_SHORTCUT_TYPES.NONE] },
};

export default Component.extend({
  tagName: "",

  userTimezone: null,

  onTimeSelected: null,

  selectedShortcut: null,
  selectedTime: null,
  selectedDate: null,
  selectedDatetime: null,
  prefilledDatetime: null,

  hiddenOptions: null,
  customOptions: null,

  lastCustomDate: null,
  lastCustomTime: null,
  parsedLastCustomDatetime: null,
  customDate: null,
  customTime: null,

  _itsatrap: null,

  defaultCustomReminderTime: `0${START_OF_DAY_HOUR}:00`,

  @on("init")
  _setupPicker() {
    this.setProperties({
      customTime: this.defaultCustomReminderTime,
      userTimezone: this.currentUser.resolvedTimezone(this.currentUser),
      hiddenOptions: this.hiddenOptions || [],
      customOptions: this.customOptions || [],
      customLabels: this.customLabels || {},
    });

    if (this.prefilledDatetime) {
      this.parsePrefilledDatetime();
    }

    this._bindKeyboardShortcuts();
  },

  @observes("prefilledDatetime")
  prefilledDatetimeChanged() {
    if (this.prefilledDatetime) {
      this.parsePrefilledDatetime();
    } else {
      this.setProperties({
        customDate: null,
        customTime: null,
        selectedShortcut: null,
      });
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this._itsatrap.unbind(Object.keys(BINDINGS));
  },

  parsePrefilledDatetime() {
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
  },

  _loadLastUsedCustomDatetime() {
    let lastTime = localStorage.lastCustomTime;
    let lastDate = localStorage.lastCustomDate;

    if (lastTime && lastDate) {
      let parsed = parseCustomDatetime(lastDate, lastTime, this.userTimezone);

      if (!parsed.isValid() || parsed < now(this.userTimezone)) {
        return;
      }

      this.setProperties({
        lastCustomDate: lastDate,
        lastCustomTime: lastTime,
        parsedLastCustomDatetime: parsed,
      });
    }
  },

  _bindKeyboardShortcuts() {
    Object.keys(BINDINGS).forEach((shortcut) => {
      this._itsatrap.bind(shortcut, () => {
        let binding = BINDINGS[shortcut];
        this.send(binding.handler, ...binding.args);
        return false;
      });
    });
  },

  customDatetimeSelected: equal("selectedShortcut", TIME_SHORTCUT_TYPES.CUSTOM),
  relativeTimeSelected: equal("selectedShortcut", TIME_SHORTCUT_TYPES.RELATIVE),
  customDatetimeFilled: and("customDate", "customTime"),

  @observes("customDate", "customTime")
  customDatetimeChanged() {
    if (!this.customDatetimeFilled) {
      return;
    }
    this.selectShortcut(TIME_SHORTCUT_TYPES.CUSTOM);
  },

  @discourseComputed(
    "hiddenOptions",
    "customOptions",
    "customLabels",
    "userTimezone"
  )
  options(hiddenOptions, customOptions, customLabels, userTimezone) {
    this._loadLastUsedCustomDatetime();

    let options = defaultShortcutOptions(userTimezone);
    this._hideDynamicOptions(options);
    options = options.concat(customOptions);

    options.sort((a, b) => {
      if (a.time < b.time) {
        return -1;
      }
      if (a.time > b.time) {
        return 1;
      }
      return 0;
    });

    let specialOptions = specialShortcutOptions();

    if (this.lastCustomDate && this.lastCustomTime) {
      let lastCustom = specialOptions.findBy(
        "id",
        TIME_SHORTCUT_TYPES.LAST_CUSTOM
      );
      lastCustom.time = this.parsedLastCustomDatetime;
      lastCustom.timeFormatKey = "dates.long_no_year";
      lastCustom.hidden = false;
    }

    options = options.concat(specialOptions);

    if (hiddenOptions.length > 0) {
      options.forEach((opt) => {
        if (hiddenOptions.includes(opt.id)) {
          opt.hidden = true;
        }
      });
    }

    this._applyCustomLabels(options, customLabels);
    this._formatTime(options);
    return options;
  },

  @action
  relativeTimeChanged(relativeTimeMins) {
    let dateTime = now(this.userTimezone).add(relativeTimeMins, "minutes");

    this.set("selectedDatetime", dateTime);

    if (this.onTimeSelected) {
      this.onTimeSelected(TIME_SHORTCUT_TYPES.RELATIVE, dateTime);
    }
  },

  @action
  selectShortcut(type) {
    if (this.options.filterBy("hidden").mapBy("id").includes(type)) {
      return;
    }

    let dateTime = null;
    if (type === TIME_SHORTCUT_TYPES.CUSTOM) {
      this.set("customTime", this.customTime || this.defaultCustomReminderTime);
      const customDatetime = parseCustomDatetime(
        this.customDate,
        this.customTime,
        this.userTimezone
      );

      if (customDatetime.isValid() && this.customDate) {
        dateTime = customDatetime;

        localStorage.lastCustomTime = this.customTime;
        localStorage.lastCustomDate = this.customDate;
      }
    } else {
      dateTime = this.options.findBy("id", type).time;
    }

    this.setProperties({
      selectedShortcut: type,
      selectedDatetime: dateTime,
    });

    if (this.onTimeSelected) {
      this.onTimeSelected(type, dateTime);
    }
  },

  _applyCustomLabels(options, customLabels) {
    options.forEach((option) => {
      if (customLabels[option.id]) {
        option.label = customLabels[option.id];
      }
    });
  },

  _formatTime(options) {
    options.forEach((option) => {
      if (option.time && option.timeFormatKey) {
        option.timeFormatted = option.time.format(I18n.t(option.timeFormatKey));
      }
    });
  },

  _hideDynamicOptions(options) {
    if (now(this.userTimezone).hour() >= LATER_TODAY_CUTOFF_HOUR) {
      this._hideOption(options, TIME_SHORTCUT_TYPES.LATER_TODAY);
    }

    if (now(this.userTimezone).day() >= MOMENT_THURSDAY) {
      this._hideOption(options, TIME_SHORTCUT_TYPES.LATER_THIS_WEEK);
    }

    if (now(this.userTimezone).day() >= MOMENT_FRIDAY) {
      this._hideOption(options, TIME_SHORTCUT_TYPES.THIS_WEEKEND);
    }
  },

  _hideOption(options, optionId) {
    const option = options.findBy("id", optionId);
    option.hidden = true;
  },
});
