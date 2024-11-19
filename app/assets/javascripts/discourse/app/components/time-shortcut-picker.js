import Component from "@ember/component";
import { action } from "@ember/object";
import { and, equal } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import {
  defaultTimeShortcuts,
  formatTime,
  hideDynamicTimeShortcuts,
  specialShortcutOptions,
  TIME_SHORTCUT_TYPES,
} from "discourse/lib/time-shortcut";
import { laterToday, now, parseCustomDatetime } from "discourse/lib/time-utils";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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

@tagName("")
export default class TimeShortcutPicker extends Component {
  @equal("selectedShortcut", TIME_SHORTCUT_TYPES.CUSTOM) customDatetimeSelected;
  @equal("selectedShortcut", TIME_SHORTCUT_TYPES.RELATIVE)
  relativeTimeSelected;
  @and("customDate", "customTime") customDatetimeFilled;

  userTimezone = null;

  onTimeSelected = null;

  selectedShortcut = null;
  selectedTime = null;
  selectedDate = null;
  selectedDatetime = null;
  prefilledDatetime = null;
  selectedDurationMins = null;

  hiddenOptions = null;
  customOptions = null;

  lastCustomDate = null;
  lastCustomTime = null;
  parsedLastCustomDatetime = null;
  customDate = null;
  customTime = null;

  _itsatrap = null;

  @on("init")
  _setupPicker() {
    this.setProperties({
      userTimezone: this.currentUser.user_option.timezone,
      hiddenOptions: this.hiddenOptions || [],
      customOptions: this.customOptions || [],
      customLabels: this.customLabels || {},
    });

    if (this.prefilledDatetime) {
      this.parsePrefilledDatetime();
    }

    this._bindKeyboardShortcuts();
  }

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
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this._itsatrap.unbind(Object.keys(BINDINGS));
  }

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
  }

  _loadLastUsedCustomDatetime() {
    const lastTime = this.keyValueStore.lastCustomTime;
    const lastDate = this.keyValueStore.lastCustomDate;

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
  }

  _bindKeyboardShortcuts() {
    Object.keys(BINDINGS).forEach((shortcut) => {
      this._itsatrap.bind(shortcut, () => {
        let binding = BINDINGS[shortcut];
        this.send(binding.handler, ...binding.args);
        return false;
      });
    });
  }

  @observes("customDate", "customTime")
  customDatetimeChanged() {
    if (!this.customDatetimeFilled) {
      return;
    }
    this.selectShortcut(TIME_SHORTCUT_TYPES.CUSTOM);
  }

  @discourseComputed(
    "timeShortcuts",
    "hiddenOptions",
    "customLabels",
    "userTimezone"
  )
  options(timeShortcuts, hiddenOptions, customLabels, userTimezone) {
    this._loadLastUsedCustomDatetime();

    let options;
    if (timeShortcuts && timeShortcuts.length) {
      options = timeShortcuts;
    } else {
      options = defaultTimeShortcuts(userTimezone);
    }
    options = hideDynamicTimeShortcuts(
      options,
      userTimezone,
      this.siteSettings
    );

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
    options.forEach((o) => (o.timeFormatted = formatTime(o)));
    return options;
  }

  @action
  relativeTimeChanged(relativeTimeMins) {
    const dateTime = now(this.userTimezone).add(relativeTimeMins, "minutes");

    this.setProperties({
      selectedDurationMins: relativeTimeMins,
      selectedDatetime: dateTime,
    });

    this.onTimeSelected?.(TIME_SHORTCUT_TYPES.RELATIVE, dateTime);
  }

  @action
  selectShortcut(type) {
    if (this.options.filterBy("hidden").mapBy("id").includes(type)) {
      return;
    }

    let dateTime = null;
    if (type === TIME_SHORTCUT_TYPES.CUSTOM) {
      const defaultCustomDateTime = this._defaultCustomDateTime();
      this.set(
        "customDate",
        this.customDate || defaultCustomDateTime.format("YYYY-MM-DD")
      );
      this.set(
        "customTime",
        this.customTime || defaultCustomDateTime.format("HH:mm")
      );

      const customDatetime = parseCustomDatetime(
        this.customDate,
        this.customTime,
        this.userTimezone
      );

      if (customDatetime.isValid() && this.customDate) {
        dateTime = customDatetime;

        this.keyValueStore.lastCustomTime = this.customTime;
        this.keyValueStore.lastCustomDate = this.customDate;
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
  }

  _applyCustomLabels(options, customLabels) {
    options.forEach((option) => {
      if (customLabels[option.id]) {
        option.label = customLabels[option.id];
      }
    });
  }

  _formatTime(options) {
    options.forEach((option) => {
      if (option.time && option.timeFormatKey) {
        option.timeFormatted = option.time.format(i18n(option.timeFormatKey));
      }
    });
  }

  _defaultCustomDateTime() {
    return moment.tz(this.userTimezone).add(1, "hour");
  }
}
