import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const DOW_SHORT = ["S", "M", "T", "W", "T", "F", "S"];

export default class SiteTrafficCustomRangeModal extends Component {
  @tracked viewMonth = this._initialViewMonth();
  @tracked startDate = this._initialDate(this.args.model.startDate);
  @tracked endDate = this._initialDate(this.args.model.endDate);
  @tracked hoverDate = null;

  cellClass = (cell) => {
    if (cell.blank) {
      return "site-traffic-custom-range__cell is-blank";
    }
    const classes = ["site-traffic-custom-range__cell"];
    const date = cell.date;
    if (date.isAfter(this.today, "day")) {
      classes.push("is-disabled");
    }
    if (date.isSame(this.today, "day")) {
      classes.push("is-today");
    }
    if (this.startDate && date.isSame(this.startDate, "day")) {
      classes.push("is-start");
    }
    if (this.endDate && date.isSame(this.endDate, "day")) {
      classes.push("is-end");
    }
    if (this._isInRange(date)) {
      classes.push("is-in-range");
    }
    return classes.join(" ");
  };

  cellDisabled = (cell) => {
    return cell.blank || cell.date.isAfter(this.today, "day");
  };

  _initialViewMonth() {
    const anchor = this.args.model.endDate || moment.utc();
    return moment.utc(anchor).startOf("month");
  }

  _initialDate(d) {
    return d ? moment.utc(d).startOf("day") : null;
  }

  get today() {
    return moment.utc().startOf("day");
  }

  get leftMonth() {
    return this.viewMonth.clone().subtract(1, "month");
  }

  get rightMonth() {
    return this.viewMonth.clone();
  }

  get leftCells() {
    return this._monthCells(this.leftMonth);
  }

  get rightCells() {
    return this._monthCells(this.rightMonth);
  }

  get leftTitle() {
    return this.leftMonth.format("MMMM YYYY");
  }

  get rightTitle() {
    return this.rightMonth.format("MMMM YYYY");
  }

  get summaryText() {
    if (!this.startDate) {
      return i18n("admin.dashboard.site_traffic.custom_range.pick_start");
    }
    if (!this.endDate) {
      return i18n("admin.dashboard.site_traffic.custom_range.pick_end", {
        start: this.startDate.format("ll"),
      });
    }
    return i18n("admin.dashboard.site_traffic.custom_range.range", {
      start: this.startDate.format("ll"),
      end: this.endDate.format("ll"),
    });
  }

  get applyDisabled() {
    return !this.startDate || !this.endDate;
  }

  _monthCells(monthMoment) {
    const monthStart = monthMoment.clone().startOf("month");
    const firstDayOfWeek = monthStart.day();
    const daysInMonth = monthStart.daysInMonth();
    const cells = [];
    for (let i = 0; i < firstDayOfWeek; i++) {
      cells.push({ blank: true, key: `blank-${i}` });
    }
    for (let d = 1; d <= daysInMonth; d++) {
      cells.push({
        blank: false,
        date: monthStart.clone().date(d),
        label: d,
        key: `d-${monthMoment.format("YYYY-MM")}-${d}`,
      });
    }
    return cells;
  }

  _isInRange(date) {
    if (!this.startDate) {
      return false;
    }
    let endBound = this.endDate;
    if (!endBound && this.hoverDate) {
      endBound = this.hoverDate.isAfter(this.startDate)
        ? this.hoverDate
        : this.startDate;
    }
    if (!endBound) {
      return false;
    }
    const lower = this.startDate.isBefore(endBound) ? this.startDate : endBound;
    const upper = this.startDate.isBefore(endBound) ? endBound : this.startDate;
    return date.isBetween(lower, upper, "day", "[]");
  }

  @action
  prevView() {
    this.viewMonth = this.viewMonth.clone().subtract(1, "month");
  }

  @action
  nextView() {
    // Don't allow advancing past today's month on the right side.
    const next = this.viewMonth.clone().add(1, "month");
    if (next.startOf("month").isAfter(this.today, "month")) {
      return;
    }
    this.viewMonth = next;
  }

  get nextDisabled() {
    return this.viewMonth
      .clone()
      .add(1, "month")
      .startOf("month")
      .isAfter(this.today, "month");
  }

  @action
  selectDate(cell) {
    if (cell.blank) {
      return;
    }
    const date = cell.date;
    if (date.isAfter(this.today, "day")) {
      return;
    }
    if (!this.startDate || (this.startDate && this.endDate)) {
      // Begin a new range selection
      this.startDate = date;
      this.endDate = null;
      this.hoverDate = null;
      return;
    }
    // Have start, no end — close out the range
    if (date.isBefore(this.startDate, "day")) {
      this.endDate = this.startDate;
      this.startDate = date;
    } else {
      this.endDate = date;
    }
    this.hoverDate = null;
  }

  @action
  hoverEnter(cell) {
    if (cell.blank) {
      return;
    }
    if (this.startDate && !this.endDate) {
      this.hoverDate = cell.date;
    }
  }

  @action
  hoverLeave() {
    this.hoverDate = null;
  }

  @action
  apply() {
    if (this.applyDisabled) {
      return;
    }
    this.args.model.setCustomDateRange(
      this.startDate.toDate(),
      this.endDate.toDate()
    );
    this.args.closeModal();
  }

  <template>
    <DModal
      class="site-traffic-custom-range-modal"
      @title={{i18n "admin.dashboard.site_traffic.custom_range.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="site-traffic-custom-range">
          <div class="site-traffic-custom-range__nav">
            <DButton
              @icon="chevron-left"
              @action={{this.prevView}}
              class="btn-flat"
            />
            <div class="site-traffic-custom-range__titles">
              <span>{{this.leftTitle}}</span>
              <span>{{this.rightTitle}}</span>
            </div>
            <DButton
              @icon="chevron-right"
              @action={{this.nextView}}
              @disabled={{this.nextDisabled}}
              class="btn-flat"
            />
          </div>

          <div
            class="site-traffic-custom-range__months"
            {{on "mouseleave" this.hoverLeave}}
          >
            <div class="site-traffic-custom-range__month">
              <div class="site-traffic-custom-range__dow">
                {{#each DOW_SHORT key="@index" as |d|}}
                  <span class="site-traffic-custom-range__dow-cell">{{d}}</span>
                {{/each}}
              </div>
              <div class="site-traffic-custom-range__grid">
                {{#each this.leftCells key="key" as |cell|}}
                  {{#if cell.blank}}
                    <span
                      class="site-traffic-custom-range__cell is-blank"
                    ></span>
                  {{else}}
                    <button
                      type="button"
                      class={{this.cellClass cell}}
                      disabled={{this.cellDisabled cell}}
                      {{on "click" (fn this.selectDate cell)}}
                      {{on "mouseenter" (fn this.hoverEnter cell)}}
                    >
                      {{cell.label}}
                    </button>
                  {{/if}}
                {{/each}}
              </div>
            </div>
            <div class="site-traffic-custom-range__month">
              <div class="site-traffic-custom-range__dow">
                {{#each DOW_SHORT key="@index" as |d|}}
                  <span class="site-traffic-custom-range__dow-cell">{{d}}</span>
                {{/each}}
              </div>
              <div class="site-traffic-custom-range__grid">
                {{#each this.rightCells key="key" as |cell|}}
                  {{#if cell.blank}}
                    <span
                      class="site-traffic-custom-range__cell is-blank"
                    ></span>
                  {{else}}
                    <button
                      type="button"
                      class={{this.cellClass cell}}
                      disabled={{this.cellDisabled cell}}
                      {{on "click" (fn this.selectDate cell)}}
                      {{on "mouseenter" (fn this.hoverEnter cell)}}
                    >
                      {{cell.label}}
                    </button>
                  {{/if}}
                {{/each}}
              </div>
            </div>
          </div>

          <div class="site-traffic-custom-range__summary">
            {{this.summaryText}}
          </div>
        </div>
      </:body>
      <:footer>
        <DButton
          @label="admin.dashboard.site_traffic.custom_range.cancel"
          @action={{@closeModal}}
          class="btn-flat"
        />
        <DButton
          @label="admin.dashboard.site_traffic.custom_range.apply"
          @action={{this.apply}}
          @disabled={{this.applyDisabled}}
        />
      </:footer>
    </DModal>
  </template>
}
