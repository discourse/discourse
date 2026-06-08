import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

function toDayMoment(value) {
  return value ? moment(value).startOf("day") : null;
}

function formatDate(value, pattern) {
  return value ? moment(value).format(pattern) : "";
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

  get presetItems() {
    const activeId = this.committed ? (this.args.activePreset ?? null) : null;
    return (this.args.presets ?? []).map((preset) => ({
      ...preset,
      active: preset.id === activeId,
    }));
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

  get applyDisabled() {
    if (!this.pendingStart || !this.pendingEnd) {
      return true;
    }
    if (!this.args.from || !this.args.to) {
      return false;
    }
    return (
      this.pendingStart.isSame(toDayMoment(this.args.from), "day") &&
      this.pendingEnd.isSame(toDayMoment(this.args.to), "day")
    );
  }

  get showTwoMonths() {
    return !this.site.mobileView;
  }

  get viewStartMonth() {
    if (this.viewStartMonthOverride) {
      return this.viewStartMonthOverride;
    }
    const anchor = toDayMoment(this.args.from) ?? moment().startOf("day");
    return anchor.clone().startOf("month");
  }

  get visibleMonths() {
    const months = [this.viewStartMonth.clone()];
    if (this.showTwoMonths) {
      months.push(this.viewStartMonth.clone().add(1, "month"));
    }
    return months;
  }

  get lastMonthIndex() {
    return this.visibleMonths.length - 1;
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
    if (
      this.committed ||
      this.pendingEnd ||
      !this.hoveredDay ||
      this.hoveredDay.isBefore(this.pendingStart, "day")
    ) {
      return null;
    }
    return this.hoveredDay;
  }

  get hoverRangeStart() {
    return this.hoverRangeEnd ? this.pendingStart : null;
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
  isMonthStartDay(day) {
    return day.date() === 1;
  }

  @action
  isMonthEndDay(day) {
    return day.date() === day.daysInMonth();
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
  isHoverEndDay(day) {
    return (
      this.hoverRangeStart &&
      this.hoverRangeEnd &&
      day.isSame(this.hoverRangeEnd, "day") &&
      day.isAfter(this.hoverRangeStart, "day")
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
    if (this.isHoverEndDay(day)) {
      classes.push("--hover-end");
    }
    if (this.isMonthStartDay(day)) {
      classes.push("--month-start");
    }
    if (this.isMonthEndDay(day)) {
      classes.push("--month-end");
    }
    return classes.join(" ");
  }

  @action
  selectPreset(preset) {
    this.args.onApply?.({ preset: preset.id });
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
  focusStartInput() {
    const start = this.currentStart;
    if (!start) {
      return;
    }
    this.viewStartMonthOverride = start.clone().startOf("month");
  }

  @action
  focusEndInput() {
    const end = this.currentEnd;
    if (!end) {
      return;
    }
    const month = end.clone().startOf("month");
    this.viewStartMonthOverride = this.showTwoMonths
      ? month.clone().subtract(1, "month")
      : month;
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
      <div
        class="d-date-range-picker__presets"
        role="group"
        aria-label={{i18n "date_range_picker.presets.label"}}
        {{this.scrollActivePresetIntoView}}
      >
        {{#each this.presetItems as |preset|}}
          <button
            type="button"
            class={{dConcatClass
              "d-date-range-picker__preset"
              (if preset.active "is-active")
            }}
            aria-current={{if preset.active "true"}}
            {{on "click" (fn this.selectPreset preset)}}
          >
            {{preset.label}}
          </button>
        {{/each}}
      </div>

      <div class="d-date-range-picker__body">
        <div
          class="d-date-range-picker__calendar"
          {{on "mouseleave" this.leaveGrid}}
        >
          <div class="d-date-range-picker__months">
            {{#each this.visibleMonths as |month index|}}
              <div class="d-date-range-picker__month">
                <div class="d-date-range-picker__month-header">
                  {{#if (eq index 0)}}
                    <DButton
                      class="btn-transparent d-date-range-picker__nav --prev"
                      @icon="chevron-left"
                      @ariaLabel="dates.previous_month"
                      @action={{fn this.shiftMonth -1}}
                    />
                  {{/if}}
                  <span class="d-date-range-picker__month-title">
                    {{formatDate month "MMMM YYYY"}}
                  </span>
                  {{#if (eq index this.lastMonthIndex)}}
                    <DButton
                      class="btn-transparent d-date-range-picker__nav --next"
                      @icon="chevron-right"
                      @ariaLabel="dates.next_month"
                      @action={{fn this.shiftMonth 1}}
                    />
                  {{/if}}
                </div>
                <div class="d-date-range-picker__weekdays" aria-hidden="true">
                  {{#each this.weekdayLabels as |dow|}}
                    <span>{{dow}}</span>
                  {{/each}}
                </div>
                <div
                  class="d-date-range-picker__grid"
                  role="grid"
                  aria-label={{formatDate month "MMMM YYYY"}}
                  {{on "keydown" this.handleKeyDown}}
                >
                  {{#each (this.weeksFor month) as |week|}}
                    <div class="d-date-range-picker__week" role="row">
                      {{#each week as |day|}}
                        {{#if (this.isMutedDay day month)}}
                          <span aria-hidden="true"></span>
                        {{else}}
                          <button
                            type="button"
                            role="gridcell"
                            class={{this.dayClass day}}
                            tabindex={{if (this.isFocusedDay day) "0" "-1"}}
                            aria-selected={{this.isAriaSelected day}}
                            aria-disabled={{if (this.isDisabledDay day) "true"}}
                            aria-label={{formatDate day "LL"}}
                            disabled={{this.isDisabledDay day}}
                            {{this.focusDay
                              (this.shouldProgrammaticallyFocusDay day)
                            }}
                            {{on "click" (fn this.clickDay day)}}
                            {{on "mouseenter" (fn this.hoverDay day)}}
                          >
                            {{formatDate day "D"}}
                          </button>
                        {{/if}}
                      {{/each}}
                    </div>
                  {{/each}}
                </div>
              </div>
            {{/each}}
          </div>
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
            {{on "focus" this.focusStartInput}}
            {{on "change" this.commitStartInput}}
            {{on "keydown" this.commitInputOnEnter}}
          />
          <input
            type="text"
            class="d-date-range-picker__input"
            inputmode="numeric"
            autocomplete="off"
            placeholder={{i18n "date_range_picker.date_placeholder"}}
            aria-label={{i18n "date_range_picker.end_date"}}
            value={{this.endInputValue}}
            {{on "focus" this.focusEndInput}}
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
