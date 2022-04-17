import Component from "@ember/component";
import { action } from "@ember/object";
import { and, empty, equal } from "@ember/object/computed";
import {
  formatTime,
  processDynamicTimeframes,
} from "discourse/lib/timeframes-builder";
import I18n from "I18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import discourseComputed from "discourse-common/utils/decorators";
import {
  extendedDefaultTimeShortcuts,
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";

export default Component.extend({
  selection: null,
  includeDateTime: true,
  isCustom: equal("selection", "custom"),
  displayDateAndTimePicker: and("includeDateTime", "isCustom"),
  displayLabel: null,
  labelClasses: null,
  timeInputDisabled: empty("_date"),
  userTimezone: null,

  _date: null,
  _time: null,

  init() {
    this._super(...arguments);
    this.userTimezone = this.currentUser.resolvedTimezone(this.currentUser);

    if (this.input) {
      const dateTime = moment(this.input);
      const closestShortcut = this._findClosestShortcut(dateTime);
      if (closestShortcut) {
        this.set("selection", closestShortcut.id);
      } else {
        this.setProperties({
          selection: TIME_SHORTCUT_TYPES.CUSTOM,
          _date: dateTime.format("YYYY-MM-DD"),
          _time: dateTime.format("HH:mm"),
        });
      }
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.label) {
      this.set("displayLabel", I18n.t(this.label));
    }
  },

  @discourseComputed("customShortcuts")
  shortcuts(customShortcuts) {
    let shortcuts;
    if (customShortcuts && customShortcuts.length) {
      shortcuts = customShortcuts;
    } else {
      shortcuts = extendedDefaultTimeShortcuts(this.userTimezone);
    }

    const shortcutsFactory = timeShortcuts(this.userTimezone);
    if (this.includeDateTime) {
      shortcuts.push(shortcutsFactory.custom());
    }
    if (this.includeNow) {
      shortcuts.push(shortcutsFactory.now());
    }

    processDynamicTimeframes(shortcuts, this.userTimezone);
    formatTime(shortcuts);

    return shortcuts
      .filter((t) => !t.hidden)
      .map((tf) => {
        return {
          id: tf.id,
          name: I18n.t(tf.label),
          time: tf.time,
          timeFormatted: tf.timeFormatted,
          icon: tf.icons,
        };
      });
  },

  @action
  onChangeDate(date) {
    if (!date) {
      this.set("time", null);
    }

    this._dateTimeChanged(date, this.time);
  },

  @action
  onChangeTime(time) {
    if (this._date) {
      this._dateTimeChanged(this._date, time);
    }
  },

  _dateTimeChanged(date, time) {
    time = time ? ` ${time}` : "";
    const dateTime = moment(`${date}${time}`);

    if (dateTime.isValid()) {
      this.attrs.onChangeInput &&
        this.attrs.onChangeInput(dateTime.format(FORMAT));
    } else {
      this.attrs.onChangeInput && this.attrs.onChangeInput(null);
    }
  },

  _findClosestShortcut(dateTime) {
    return this.shortcuts.find((tf) => {
      if (tf.time) {
        const diff = tf.time.diff(dateTime);
        return 0 <= diff && diff < 60 * 1000;
      }
    });
  },
});
