import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import type { ComponentLike } from "@glint/template";
import type { Moment } from "moment";
import DatePickerFutureUntyped from "discourse/components/date-picker-future";
import withEventValue from "discourse/helpers/with-event-value";
import {
  extendedDefaultTimeShortcuts,
  formatTime,
  hideDynamicTimeShortcuts,
  TIME_SHORTCUT_TYPES,
  timeShortcuts,
} from "discourse/lib/time-shortcut";
import type User from "discourse/models/user";
import FutureDateInputSelectorUntyped, {
  FORMAT,
} from "discourse/select-kit/components/future-date-input-selector";
import type SiteSettingsService from "discourse/services/site-settings";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/** Legacy global supplied by the application, without introducing a module import. */
declare const moment: typeof import("moment");

/**
 * A time shortcut, as built by `timeShortcuts()` from `discourse/lib/time-shortcut`.
 */
export interface DFutureDateInputShortcut {
  /** The ID of the shortcut, used as the selected value. */
  id: string;

  /** The translation key of the name of the shortcut. */
  label: string;

  /** The time the shortcut stands for, as a moment. */
  time?: unknown;

  /** The ID of the icon shown next to the shortcut. */
  icon?: string;

  /** The translation key of the format the time is shown in. */
  timeFormatKey?: string;
}

/** A shortcut as the selector shows it. */
interface SelectorShortcut {
  id: string;
  name: string;
  time: unknown;
  timeFormatted: string | null;
  icon?: string;
}

// TODO(typescript-pending): drop once DatePickerFuture is authored in .gts with a real
// Signature, then import it directly.
const DatePickerFuture = DatePickerFutureUntyped as unknown as ComponentLike<{
  Args: {
    defaultDate?: string | null;
    onSelect: (date: string | null) => void;
    value?: string | null;
  };
}>;

// TODO(typescript-pending): drop once FutureDateInputSelector is authored in .gts with
// a real Signature, then import it directly.
const FutureDateInputSelector =
  FutureDateInputSelectorUntyped as unknown as ComponentLike<{
    Args: {
      clearable?: boolean;
      content: SelectorShortcut[];
      onChange: (value: string | null) => void;
      onChangeInput?: (value: string | null) => void;
      options?: Record<string, unknown>;
      value?: string | null;
    };
  }>;

interface DFutureDateInputSignature {
  Args: {
    /**
     * The selected date and time. A new value selects the matching shortcut, or the
     * custom date and time; an empty one keeps the current selection.
     */
    input?: string | null;

    /** Called with the new date and time in the `FORMAT` of the selector, or `null`. */
    onChangeInput?: (value: string | null) => void;

    /** The translation key of the label. */
    label?: string;

    /** The CSS classes of the label. */
    labelClasses?: string;

    /** The ID of an icon shown before the label. */
    displayLabelIcon?: string;

    /** Whether the selection can be cleared. */
    clearable?: boolean;

    /** Shortcuts shown instead of the default ones. */
    customShortcuts?: DFutureDateInputShortcut[];

    /** Whether to offer a custom date and time. Defaults to `true`. */
    includeDateTime?: boolean;

    /** Whether to offer the current time. */
    includeNow?: boolean;

    /** Whether to show only the date and time pickers, without the shortcuts. */
    noRelativeOptions?: boolean;
  };
  Element: HTMLDivElement;
}

/** The selection and the custom date and time. */
class InputState {
  @tracked date: string | null = null;
  @tracked selection: string | null = null;
  @tracked time: string | null = null;
}

/**
 * A select of time shortcuts (later today, tomorrow, next month…) with optional date
 * and time pickers for a custom value.
 */
export default class DFutureDateInput extends Component<DFutureDateInputSignature> {
  @service declare currentUser: User;
  @service declare siteSettings: SiteSettingsService;

  #state = new InputState();
  #userTimezone: string | null | undefined;

  constructor(owner: Owner, args: DFutureDateInputSignature["Args"]) {
    super(owner, args);
    this.#userTimezone = this.currentUser.user_option!.timezone;
  }

  get includeDateTime() {
    return this.args.includeDateTime ?? true;
  }

  get displayLabel() {
    return this.args.label ? i18n(this.args.label) : null;
  }

  /**
   * Follows a new `@input`, but survives an empty one: the date and time pickers of a
   * picked "custom" stay open when the input is cleared.
   */
  @cached
  get state() {
    if (this.args.input) {
      // An untracked latch, so the write can't dirty a tag the render has read.
      // eslint-disable-next-line ember/no-side-effects
      this.#state = this.#stateFromInput(this.args.input);
    }

    return this.#state;
  }

  get isCustom() {
    return this.state.selection === "custom";
  }

  get displayDateAndTimePicker() {
    return this.includeDateTime && this.isCustom;
  }

  get timeInputDisabled() {
    return isEmpty(this.state.date);
  }

  @cached
  get shortcuts(): SelectorShortcut[] {
    let shortcuts: DFutureDateInputShortcut[];
    if (this.args.customShortcuts && this.args.customShortcuts.length) {
      shortcuts = [...this.args.customShortcuts];
    } else {
      shortcuts = extendedDefaultTimeShortcuts(this.#userTimezone);
    }

    const shortcutsFactory = timeShortcuts(this.#userTimezone);
    if (this.includeDateTime) {
      shortcuts.push(shortcutsFactory.custom());
    }
    if (this.args.includeNow) {
      shortcuts.push(shortcutsFactory.now());
    }

    shortcuts = hideDynamicTimeShortcuts(
      shortcuts,
      this.#userTimezone,
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
  onChangeSelection(selection: string | null) {
    this.state.selection = selection;
  }

  @action
  onChangeDate(date: string | null) {
    if (!date) {
      this.state.time = null;
    }

    this.#dateTimeChanged(date, this.state.time);
  }

  @action
  onChangeTime(time: string) {
    if (this.state.date) {
      this.#dateTimeChanged(this.state.date, time);
    }
  }

  #stateFromInput(input: string) {
    const state = new InputState();
    const dateTime = moment(input);
    const closestShortcut = this.#findClosestShortcut(dateTime);
    if (!this.args.noRelativeOptions && closestShortcut) {
      state.selection = closestShortcut.id;
    } else {
      state.selection = TIME_SHORTCUT_TYPES.CUSTOM;
      state.date = dateTime.format("YYYY-MM-DD");
      state.time = dateTime.format("HH:mm");
    }

    return state;
  }

  #dateTimeChanged(date: string | null, time: string | null) {
    time = time ? ` ${time}` : "";
    const dateTime = moment(`${date}${time}`);

    if (dateTime.isValid()) {
      this.args.onChangeInput?.(dateTime.format(FORMAT));
    } else {
      this.args.onChangeInput?.(null);
    }
  }

  #findClosestShortcut(dateTime: Moment) {
    return this.shortcuts.find((tf) => {
      if (tf.time) {
        const diff = (tf.time as Moment).diff(dateTime);
        return 0 <= diff && diff < 60 * 1000;
      }
    });
  }

  <template>
    <div class="future-date-input" ...attributes>
      {{#unless @noRelativeOptions}}
        <div class="control-group">
          <label class={{@labelClasses}}>
            {{#if @displayLabelIcon}}{{dIcon
                @displayLabelIcon
              }}{{/if}}{{this.displayLabel}}
          </label>
          <FutureDateInputSelector
            @clearable={{@clearable}}
            @content={{this.shortcuts}}
            @onChange={{this.onChangeSelection}}
            @onChangeInput={{@onChangeInput}}
            @options={{hash none="time_shortcut.select_timeframe"}}
            @value={{this.state.selection}}
          />
        </div>
      {{/unless}}

      {{#if this.displayDateAndTimePicker}}
        <div class="control-group future-date-input-date-picker">
          {{dIcon "calendar-days"}}
          <DatePickerFuture
            @defaultDate={{this.state.date}}
            @onSelect={{this.onChangeDate}}
            @value={{this.state.date}}
          />
        </div>

        <div class="control-group future-date-input-time-picker">
          {{dIcon "far-clock"}}
          <Input
            class="time-input"
            disabled={{this.timeInputDisabled}}
            placeholder="--:--"
            @type="time"
            @value={{this.state.time}}
            {{on "input" (withEventValue this.onChangeTime)}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
