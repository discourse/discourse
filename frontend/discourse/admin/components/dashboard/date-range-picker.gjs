import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export const PRESET_LAST_7_DAYS = "last_7_days";
export const PRESET_LAST_30_DAYS = "last_30_days";
export const PRESET_LAST_3_MONTHS = "last_3_months";
export const PRESET_LAST_6_MONTHS = "last_6_months";
export const PRESET_LAST_YEAR = "last_year";

export const ALL_PRESETS = [
  PRESET_LAST_7_DAYS,
  PRESET_LAST_30_DAYS,
  PRESET_LAST_3_MONTHS,
  PRESET_LAST_6_MONTHS,
  PRESET_LAST_YEAR,
];

const PRESET_RANGES = {
  [PRESET_LAST_7_DAYS]: (today) => ({
    from: today.clone().subtract(6, "days"),
    to: today.clone(),
  }),
  [PRESET_LAST_30_DAYS]: (today) => ({
    from: today.clone().subtract(29, "days"),
    to: today.clone(),
  }),
  [PRESET_LAST_3_MONTHS]: (today) => ({
    from: today.clone().subtract(3, "months").add(1, "day"),
    to: today.clone(),
  }),
  [PRESET_LAST_6_MONTHS]: (today) => ({
    from: today.clone().subtract(6, "months").add(1, "day"),
    to: today.clone(),
  }),
  [PRESET_LAST_YEAR]: (today) => ({
    from: today.clone().subtract(1, "year").add(1, "day"),
    to: today.clone(),
  }),
};

const PRESET_LABEL_KEYS = {
  [PRESET_LAST_7_DAYS]: "date_range_picker.presets.last_7_days",
  [PRESET_LAST_30_DAYS]: "date_range_picker.presets.last_30_days",
  [PRESET_LAST_3_MONTHS]: "date_range_picker.presets.last_3_months",
  [PRESET_LAST_6_MONTHS]: "date_range_picker.presets.last_6_months",
  [PRESET_LAST_YEAR]: "date_range_picker.presets.last_year",
};

export function presetRange(preset, today = moment().startOf("day")) {
  return PRESET_RANGES[preset](today.clone().startOf("day"));
}

export function formatRange(from, to) {
  if (!from || !to) {
    return "";
  }
  const fromM = moment(from);
  const toM = moment(to);
  if (fromM.isSame(toM, "day")) {
    return fromM.format("ll");
  }
  return `${fromM.format("ll")} – ${toM.format("ll")}`;
}

function toDayMoment(value) {
  return value ? moment(value).startOf("day") : null;
}

function fmt(value, pattern) {
  return value ? moment(value).format(pattern) : "";
}

function ymd(value) {
  return value ? moment(value).format("YYYY-MM-DD") : null;
}

export function matchingPreset(from, to, presets, today = moment()) {
  const fromYmd = ymd(from);
  const toYmd = ymd(to);
  const todayStart = today.clone().startOf("day");
  return (
    presets.find((preset) => {
      const range = PRESET_RANGES[preset](todayStart);
      return ymd(range.from) === fromYmd && ymd(range.to) === toYmd;
    }) ?? null
  );
}

export default class DashboardDateRangePicker extends Component {
  @service site;

  @tracked pendingStart = null;
  @tracked pendingEnd = null;
  @tracked hoveredDay = null;
  @tracked focusedDay = null;
  @tracked viewStartMonthOverride = null;

  focusDay = modifier((element, [shouldFocus]) => {
    if (shouldFocus) {
      element.focus();
    }
  });

  scrollActivePresetIntoView = modifier((element) => {
    const active = element.querySelector(
      ".d-date-range-picker__preset.is-active"
    );
    if (!active) {
      return;
    }
    const railRect = element.getBoundingClientRect();
    const activeRect = active.getBoundingClientRect();
    element.scrollLeft +=
      activeRect.left - railRect.left - (railRect.width - activeRect.width) / 2;
  });

  get presets() {
    return this.args.presets ?? ALL_PRESETS;
  }

  get maxDate() {
    return toDayMoment(this.args.maxDate) ?? moment().startOf("day");
  }

  get committed() {
    return this.pendingStart === null;
  }

  get currentStart() {
    return this.committed ? toDayMoment(this.args.from) : this.pendingStart;
  }

  get currentEnd() {
    return this.committed ? toDayMoment(this.args.to) : this.pendingEnd;
  }

  get activePreset() {
    if (!this.committed) {
      return null;
    }
    return matchingPreset(this.args.from, this.args.to, this.presets);
  }

  get applyDisabled() {
    if (!this.pendingStart || !this.pendingEnd) {
      return true;
    }
    return (
      ymd(this.pendingStart) === ymd(this.args.from) &&
      ymd(this.pendingEnd) === ymd(this.args.to)
    );
  }

  get showTwoMonths() {
    return !this.site.mobileView;
  }

  get monthSpanCount() {
    const start = toDayMoment(this.args.from);
    const end = toDayMoment(this.args.to);
    if (!start || !end) {
      return 0;
    }
    return end
      .clone()
      .startOf("month")
      .diff(start.clone().startOf("month"), "months");
  }

  get useLongRangeLayout() {
    return (
      !this.viewStartMonthOverride &&
      this.showTwoMonths &&
      this.monthSpanCount > 1
    );
  }

  get viewStartMonth() {
    if (this.viewStartMonthOverride) {
      return this.viewStartMonthOverride;
    }
    const anchor = toDayMoment(this.args.to) ?? moment().startOf("day");
    if (this.showTwoMonths) {
      return anchor.clone().subtract(1, "month").startOf("month");
    }
    return anchor.clone().startOf("month");
  }

  get visibleMonths() {
    if (this.useLongRangeLayout) {
      return [
        toDayMoment(this.args.from).clone().startOf("month"),
        toDayMoment(this.args.to).clone().startOf("month"),
      ];
    }
    const months = [this.viewStartMonth.clone()];
    if (this.showTwoMonths) {
      months.push(this.viewStartMonth.clone().add(1, "month"));
    }
    return months;
  }

  get effectiveFocusedDay() {
    return (
      this.focusedDay ?? toDayMoment(this.args.to) ?? moment().startOf("day")
    );
  }

  get weekdayLabels() {
    return moment.weekdaysMin(true);
  }

  get hoverRangeEnd() {
    if (this.committed || this.pendingEnd || !this.hoveredDay) {
      return null;
    }
    return this.hoveredDay.isBefore(this.pendingStart, "day")
      ? this.pendingStart
      : this.hoveredDay;
  }

  get hoverRangeStart() {
    if (this.committed || this.pendingEnd || !this.hoveredDay) {
      return null;
    }
    return this.hoveredDay.isBefore(this.pendingStart, "day")
      ? this.hoveredDay
      : this.pendingStart;
  }

  @action
  weeksFor(monthStart) {
    const start = monthStart.clone().startOf("month").startOf("week");
    const end = monthStart.clone().endOf("month").endOf("week");
    const weeks = [];
    const cursor = start.clone();
    while (cursor.isSameOrBefore(end)) {
      const week = [];
      for (let i = 0; i < 7; i++) {
        week.push(cursor.clone());
        cursor.add(1, "day");
      }
      weeks.push(week);
    }
    return weeks;
  }

  @action
  isMutedDay(day, monthStart) {
    return !day.isSame(monthStart, "month");
  }

  @action
  isDisabledDay(day) {
    return day.isAfter(this.maxDate, "day");
  }

  @action
  isStartDay(day) {
    return this.currentStart && day.isSame(this.currentStart, "day");
  }

  @action
  isEndDay(day) {
    return this.currentEnd && day.isSame(this.currentEnd, "day");
  }

  @action
  isInRangeDay(day) {
    if (!this.currentStart || !this.currentEnd) {
      return false;
    }
    return (
      day.isAfter(this.currentStart, "day") &&
      day.isBefore(this.currentEnd, "day")
    );
  }

  @action
  isHoverPreviewDay(day) {
    if (!this.hoverRangeStart || !this.hoverRangeEnd) {
      return false;
    }
    return (
      day.isAfter(this.hoverRangeStart, "day") &&
      day.isBefore(this.hoverRangeEnd, "day")
    );
  }

  @action
  isFocusedDay(day) {
    return day.isSame(this.effectiveFocusedDay, "day");
  }

  @action
  shouldProgrammaticallyFocusDay(day) {
    return this.focusedDay !== null && day.isSame(this.focusedDay, "day");
  }

  @action
  isAriaSelected(day) {
    if (this.isStartDay(day) || this.isEndDay(day)) {
      return "true";
    }
    return "false";
  }

  @action
  dayClass(day) {
    const classes = ["d-date-range-picker__day"];
    if (this.isDisabledDay(day)) {
      classes.push("--disabled");
    }
    if (this.isStartDay(day)) {
      classes.push("--start");
    }
    if (this.isEndDay(day)) {
      classes.push("--end");
    }
    if (this.isInRangeDay(day)) {
      classes.push("--in-range");
    }
    if (this.isHoverPreviewDay(day)) {
      classes.push("--hover-preview");
    }
    return classes.join(" ");
  }

  @action
  selectPreset(preset) {
    const { from, to } = presetRange(preset);
    this.args.onApply?.({
      preset,
      from: from.toDate(),
      to: to.toDate(),
    });
  }

  @action
  clickDay(day) {
    if (this.isDisabledDay(day)) {
      return;
    }
    if (this.committed || this.pendingEnd) {
      this.pendingStart = day.clone();
      this.pendingEnd = null;
      this.focusedDay = day.clone();
      return;
    }
    if (day.isBefore(this.pendingStart, "day")) {
      this.pendingStart = day.clone();
    } else {
      this.pendingEnd = day.clone();
    }
    this.focusedDay = day.clone();
  }

  @action
  hoverDay(day) {
    if (this.committed || this.isDisabledDay(day)) {
      return;
    }
    this.hoveredDay = day.clone();
  }

  @action
  leaveGrid() {
    this.hoveredDay = null;
  }

  @action
  cancel() {
    this.pendingStart = null;
    this.pendingEnd = null;
    this.hoveredDay = null;
    this.viewStartMonthOverride = null;
    this.args.onCancel?.();
  }

  @action
  apply() {
    if (this.applyDisabled) {
      return;
    }
    this.args.onApply?.({
      preset: null,
      from: this.pendingStart.toDate(),
      to: this.pendingEnd.toDate(),
    });
  }

  @action
  shiftMonth(delta) {
    this.viewStartMonthOverride = this.viewStartMonth
      .clone()
      .add(delta, "months");
  }

  @action
  handleKeyDown(event) {
    const candidate = this.effectiveFocusedDay.clone();
    let handled = true;
    switch (event.key) {
      case "ArrowLeft":
        candidate.subtract(1, "day");
        break;
      case "ArrowRight":
        candidate.add(1, "day");
        break;
      case "ArrowUp":
        candidate.subtract(7, "days");
        break;
      case "ArrowDown":
        candidate.add(7, "days");
        break;
      case "PageUp":
        candidate.subtract(1, "month");
        break;
      case "PageDown":
        candidate.add(1, "month");
        break;
      case "Home":
        candidate.startOf("week");
        break;
      case "End":
        candidate.endOf("week");
        break;
      default:
        handled = false;
    }
    if (!handled) {
      return;
    }
    event.preventDefault();
    const target = candidate.isAfter(this.maxDate, "day")
      ? this.maxDate.clone()
      : candidate;
    this.focusedDay = target;
    this.ensureVisible(target);
  }

  ensureVisible(day) {
    const lastVisibleMonth = this.viewStartMonth
      .clone()
      .add(this.showTwoMonths ? 1 : 0, "month")
      .endOf("month");
    if (day.isBefore(this.viewStartMonth, "day")) {
      this.viewStartMonthOverride = day.clone().startOf("month");
    } else if (day.isAfter(lastVisibleMonth, "day")) {
      this.viewStartMonthOverride = day
        .clone()
        .startOf("month")
        .subtract(this.showTwoMonths ? 1 : 0, "month");
    }
  }

  get startInputValue() {
    return this.currentStart ? this.currentStart.format("YYYY/MM/DD") : "";
  }

  get endInputValue() {
    return this.currentEnd ? this.currentEnd.format("YYYY/MM/DD") : "";
  }

  parseTypedDate(value) {
    const parsed = moment(value, "YYYY/MM/DD", true);
    if (!parsed.isValid()) {
      return null;
    }
    const day = parsed.startOf("day");
    if (day.isAfter(this.maxDate, "day")) {
      return null;
    }
    return day;
  }

  @action
  commitStartInput(event) {
    const parsed = this.parseTypedDate(event.target.value);
    if (!parsed) {
      event.target.value = this.startInputValue;
      return;
    }
    const end = this.currentEnd;
    this.pendingStart = parsed;
    this.pendingEnd = end && !end.isBefore(parsed, "day") ? end.clone() : null;
    this.focusedDay = parsed.clone();
  }

  @action
  commitEndInput(event) {
    const parsed = this.parseTypedDate(event.target.value);
    const start = this.currentStart;
    if (!parsed || !start || parsed.isBefore(start, "day")) {
      event.target.value = this.endInputValue;
      return;
    }
    this.pendingStart = start.clone();
    this.pendingEnd = parsed;
    this.focusedDay = parsed.clone();
  }

  @action
  commitInputOnEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    }
  }

  <template>
    <div class="d-date-range-picker">
      <ul
        class="d-date-range-picker__presets"
        aria-label={{i18n "date_range_picker.presets.label"}}
        {{this.scrollActivePresetIntoView}}
      >
        {{#each this.presets as |preset|}}
          <li class="d-date-range-picker__preset-item">
            <button
              type="button"
              class={{dConcatClass
                "d-date-range-picker__preset"
                (if (eq this.activePreset preset) "is-active")
              }}
              aria-current={{if (eq this.activePreset preset) "true"}}
              {{on "click" (fn this.selectPreset preset)}}
            >
              {{i18n (get PRESET_LABEL_KEYS preset)}}
            </button>
          </li>
        {{/each}}
      </ul>

      <div class="d-date-range-picker__body">
        <div
          class="d-date-range-picker__calendar"
          {{on "mouseleave" this.leaveGrid}}
        >
          <button
            type="button"
            class="d-date-range-picker__nav --prev"
            aria-label={{i18n "dates.previous_month"}}
            {{on "click" (fn this.shiftMonth -1)}}
          >
            {{dIcon "chevron-left"}}
          </button>

          <div class="d-date-range-picker__months">
            {{#each this.visibleMonths as |month|}}
              <div class="d-date-range-picker__month">
                <div class="d-date-range-picker__month-header">
                  {{fmt month "MMMM YYYY"}}
                </div>
                <div class="d-date-range-picker__weekdays" aria-hidden="true">
                  {{#each this.weekdayLabels as |dow|}}
                    <span class="d-date-range-picker__weekday">{{dow}}</span>
                  {{/each}}
                </div>
                <div
                  class="d-date-range-picker__grid"
                  role="grid"
                  aria-label={{fmt month "MMMM YYYY"}}
                  {{on "keydown" this.handleKeyDown}}
                >
                  {{#each (this.weeksFor month) as |week|}}
                    <div class="d-date-range-picker__week" role="row">
                      {{#each week as |day|}}
                        {{#if (this.isMutedDay day month)}}
                          <span
                            class="d-date-range-picker__day-placeholder"
                            aria-hidden="true"
                          ></span>
                        {{else}}
                          <button
                            type="button"
                            role="gridcell"
                            class={{this.dayClass day}}
                            tabindex={{if (this.isFocusedDay day) "0" "-1"}}
                            aria-selected={{this.isAriaSelected day}}
                            aria-disabled={{if (this.isDisabledDay day) "true"}}
                            aria-label={{fmt day "LL"}}
                            disabled={{this.isDisabledDay day}}
                            {{this.focusDay
                              (this.shouldProgrammaticallyFocusDay day)
                            }}
                            {{on "click" (fn this.clickDay day)}}
                            {{on "mouseenter" (fn this.hoverDay day)}}
                          >
                            {{fmt day "D"}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/each}}
          </div>

          <button
            type="button"
            class="d-date-range-picker__nav --next"
            aria-label={{i18n "dates.next_month"}}
            {{on "click" (fn this.shiftMonth 1)}}
          >
            {{dIcon "chevron-right"}}
          </button>
        </div>

        <div class="d-date-range-picker__inputs">
          <input
            type="text"
            class="d-date-range-picker__input"
            inputmode="numeric"
            autocomplete="off"
            placeholder={{i18n "date_range_picker.date_placeholder"}}
            aria-label={{i18n "date_range_picker.start_date"}}
            value={{this.startInputValue}}
            {{on "change" this.commitStartInput}}
            {{on "keydown" this.commitInputOnEnter}}
          />
          <span class="d-date-range-picker__input-arrow" aria-hidden="true">
            {{dIcon "arrow-right"}}
          </span>
          <input
            type="text"
            class="d-date-range-picker__input"
            inputmode="numeric"
            autocomplete="off"
            placeholder={{i18n "date_range_picker.date_placeholder"}}
            aria-label={{i18n "date_range_picker.end_date"}}
            value={{this.endInputValue}}
            {{on "change" this.commitEndInput}}
            {{on "keydown" this.commitInputOnEnter}}
          />
        </div>

        <div class="d-date-range-picker__footer">
          <DButton
            @action={{this.cancel}}
            @label="cancel"
            class="btn-default d-date-range-picker__cancel"
          />
          <DButton
            @action={{this.apply}}
            @label="date_range_picker.apply"
            @disabled={{this.applyDisabled}}
            class="btn-primary d-date-range-picker__apply"
          />
        </div>
      </div>
    </div>
  </template>
}
