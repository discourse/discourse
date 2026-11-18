/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import DatePickerFuture from "discourse/components/date-picker-future";
import withEventValue from "discourse/helpers/with-event-value";
import {
  extendedDefaultTimeShortcuts,
  FORMAT,
  formatTime,
  hideDynamicTimeShortcuts,
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import { removeAccents } from "discourse/lib/utilities";
import FutureDateInputSelector from "discourse/select-kit/components/future-date-input-selector";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

@tagName("")
export default class DFutureDateInput extends Component {
  /** @type {string | null | undefined} */
  selection = null;
  includeDateTime = true;

  /** @type {string | null} */
  displayLabel = null;

  /**
   * Names the select when there is no visible `label`.
   *
   * @type {string | null | undefined}
   */
  ariaLabel = null;

  /** @type {string | null | undefined} */
  labelClasses = null;

  /** @type {string | null | undefined} */
  userTimezone = null;

  /** @type {((value: string | null) => void) | null | undefined} */
  onChangeInput = null;

  labelId = `future-date-input-label-${guidFor(this)}`;

  /** @type {string | null} */
  _date = null;

  /** @type {string | null} */
  _time = null;

  init() {
    super.init(...arguments);
    this.userTimezone = this.currentUser.user_option.timezone;
  }

  @computed("selection")
  get isCustom() {
    return this.selection === "custom";
  }

  @computed("includeDateTime", "isCustom")
  get displayDateAndTimePicker() {
    return this.includeDateTime && this.isCustom;
  }

  @computed("shortcuts", "selection")
  get heldIcon() {
    return this.shortcuts.find((shortcut) => shortcut.id === this.selection)
      ?.icon;
  }

  @computed("shortcuts")
  get shortcutOptions() {
    return this.shortcuts.map((shortcut) =>
      shortcut.timeFormatted
        ? selectOption(shortcut, { description: shortcut.timeFormatted })
        : shortcut
    );
  }

  @computed("_date")
  get timeInputDisabled() {
    return isEmpty(this._date);
  }

  @computed("customShortcuts")
  get shortcuts() {
    let shortcuts;
    if (this.customShortcuts && this.customShortcuts.length) {
      shortcuts = this.customShortcuts;
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

  /** Matches the typed text against a shortcut's name or its date. */
  @action
  filterShortcut(shortcut, term) {
    const folded = removeAccents(term);
    return [shortcut.name, shortcut.timeFormatted].some((text) =>
      removeAccents(text ?? "")
        .toLowerCase()
        .includes(folded)
    );
  }

  @action
  onChangeDate(date) {
    if (!date) {
      this.set("_time", null);
    }

    this._dateTimeChanged(date, this._time);
  }

  @action
  onChangeShortcut(id) {
    this.set("selection", id);

    if (id === null) {
      this.onChangeInput?.(null);
      return;
    }

    const time = this.shortcuts.find((shortcut) => shortcut.id === id)?.time;
    if (id !== TIME_SHORTCUT_TYPES.CUSTOM && time) {
      this.onChangeInput?.(time.locale("en").format(FORMAT));
    }
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
    <div class="future-date-input" ...attributes>
      {{#unless this.noRelativeOptions}}
        <div class="control-group">
          <label class={{this.labelClasses}} id={{this.labelId}}>
            {{#if this.displayLabelIcon}}{{dIcon
                this.displayLabelIcon
              }}{{/if}}{{this.displayLabel}}
          </label>
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelect
              class="future-date-input__select"
              @ariaLabelledBy={{if this.displayLabel this.labelId}}
              @clearable={{this.clearable}}
              @filterBy={{this.filterShortcut}}
              @icon={{this.heldIcon}}
              @identifier="future-date-input"
              @onChange={{this.onChangeShortcut}}
              @options={{this.shortcutOptions}}
              @texts={{hash
                ariaLabel=this.ariaLabel
                placeholder=(i18n "time_shortcut.select_timeframe")
              }}
              @value={{this.selection}}
              @variant="typeahead"
            >
              <:selection as |option|>
                <span class="future-date-input__selection">
                  {{option.record.name}}
                  {{#if option.record.timeFormatted}}
                    <span class="future-date-input__selection-date">
                      {{option.record.timeFormatted}}
                    </span>
                  {{/if}}
                </span>
              </:selection>
              <:option as |option|>
                <span class="future-date-input__option">
                  {{#if option.record.icon}}
                    {{dIcon option.record.icon}}
                  {{/if}}
                  {{option.record.name}}
                </span>
              </:option>
            </DSelect>
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <FutureDateInputSelector
              @clearable={{this.clearable}}
              @content={{this.shortcuts}}
              @onChange={{fn (mut this.selection)}}
              @onChangeInput={{this.onChangeInput}}
              @options={{hash none="time_shortcut.select_timeframe"}}
              @value={{readonly this.selection}}
            />
          {{/if}}
        </div>
      {{/unless}}

      {{#if this.displayDateAndTimePicker}}
        <div class="control-group future-date-input-date-picker">
          {{dIcon "calendar-days"}}
          <DatePickerFuture
            @defaultDate={{this._date}}
            @onSelect={{this.onChangeDate}}
            @value={{this._date}}
          />
        </div>

        <div class="control-group future-date-input-time-picker">
          {{dIcon "far-clock"}}
          <Input
            class="time-input"
            disabled={{this.timeInputDisabled}}
            placeholder="--:--"
            @type="time"
            @value={{this._time}}
            {{on "input" (withEventValue this.onChangeTime)}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
