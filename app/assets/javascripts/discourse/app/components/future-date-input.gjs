import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, empty, equal } from "@ember/object/computed";
import DatePickerFuture from "discourse/components/date-picker-future";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import discourseComputed from "discourse/lib/decorators";
import {
  extendedDefaultTimeShortcuts,
  formatTime,
  hideDynamicTimeShortcuts,
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { i18n } from "discourse-i18n";
import FutureDateInputSelector, {
  FORMAT,
} from "select-kit/components/future-date-input-selector";

export default class FutureDateInput extends Component {
  selection = null;
  includeDateTime = true;

  @equal("selection", "custom") isCustom;
  @and("includeDateTime", "isCustom") displayDateAndTimePicker;
  @empty("_date") timeInputDisabled;

  displayLabel = null;
  labelClasses = null;
  userTimezone = null;
  onChangeInput = null;
  _date = null;
  _time = null;

  init() {
    super.init(...arguments);
    this.userTimezone = this.currentUser.user_option.timezone;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.label) {
      this.set("displayLabel", i18n(this.label));
    }

    if (this.input) {
      const dateTime = moment(this.input);
      const closestShortcut = this._findClosestShortcut(dateTime);
      if (!this.noRelativeOptions && closestShortcut) {
        this.set("selection", closestShortcut.id);
      } else {
        this.setProperties({
          selection: TIME_SHORTCUT_TYPES.CUSTOM,
          _date: dateTime.format("YYYY-MM-DD"),
          _time: dateTime.format("HH:mm"),
        });
      }
    }
  }

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

    shortcuts = hideDynamicTimeShortcuts(
      shortcuts,
      this.userTimezone,
      this.siteSettings
    );

    return shortcuts.map((s) => {
      return {
        id: s.id,
        name: i18n(s.label),
        time: s.time,
        timeFormatted: formatTime(s),
        icon: s.icon,
      };
    });
  }

  @action
  onChangeDate(date) {
    if (!date) {
      this.set("_time", null);
    }

    this._dateTimeChanged(date, this._time);
  }

  @action
  onChangeTime(time) {
    if (this._date) {
      this._dateTimeChanged(this._date, time);
    }
  }

  _dateTimeChanged(date, time) {
    time = time ? ` ${time}` : "";
    const dateTime = moment(`${date}${time}`);

    if (dateTime.isValid()) {
      this.onChangeInput?.(dateTime.format(FORMAT));
    } else {
      this.onChangeInput?.(null);
    }
  }

  _findClosestShortcut(dateTime) {
    return this.shortcuts.find((tf) => {
      if (tf.time) {
        const diff = tf.time.diff(dateTime);
        return 0 <= diff && diff < 60 * 1000;
      }
    });
  }

  <template>
    <div class="future-date-input">
      {{#unless this.noRelativeOptions}}
        <div class="control-group">
          <label class={{this.labelClasses}}>
            {{#if this.displayLabelIcon}}{{icon
                this.displayLabelIcon
              }}{{/if}}{{this.displayLabel}}
          </label>
          <FutureDateInputSelector
            @value={{readonly this.selection}}
            @content={{this.shortcuts}}
            @clearable={{this.clearable}}
            @onChangeInput={{this.onChangeInput}}
            @onChange={{fn (mut this.selection)}}
            @options={{hash none="time_shortcut.select_timeframe"}}
          />
        </div>
      {{/unless}}

      {{#if this.displayDateAndTimePicker}}
        <div class="control-group future-date-input-date-picker">
          {{icon "calendar-days"}}
          <DatePickerFuture
            @value={{this._date}}
            @defaultDate={{this._date}}
            @onSelect={{this.onChangeDate}}
          />
        </div>

        <div class="control-group future-date-input-time-picker">
          {{icon "far-clock"}}
          <Input
            placeholder="--:--"
            @type="time"
            class="time-input"
            @value={{this._time}}
            disabled={{this.timeInputDisabled}}
            {{on "input" (withEventValue this.onChangeTime)}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
