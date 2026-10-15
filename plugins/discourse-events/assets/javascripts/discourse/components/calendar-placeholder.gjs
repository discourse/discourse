import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import DSkeleton from "discourse/ui-kit/d-skeleton";

const MONTH_WEEKS = 6;
const TIME_GRID_SLOTS = 10;
const LIST_GROUPS = [2, 1, 3, 2, 1, 2];

// Fixed rather than random so the placeholder doesn't reshuffle on rerender.
const MONTH_EVENT_PATTERN = [0, 1, 0, 0, 2, 0, 1, 0, 0, 1, 0, 0, 0, 2];
const TIME_GRID_EVENTS = [
  { column: 0, top: 10, height: 15 },
  { column: 0, top: 50, height: 20 },
  { column: 1, top: 35, height: 20 },
  { column: 2, top: 20, height: 10 },
  { column: 3, top: 55, height: 25 },
  { column: 4, top: 15, height: 20 },
  { column: 5, top: 45, height: 10 },
  { column: 6, top: 30, height: 15 },
];

function positionStyle({ top, height }) {
  return trustHTML(`top: ${top}%; height: ${height}%`);
}

export default class CalendarPlaceholder extends Component {
  get columnCount() {
    if (this.args.view === "timeGridDay") {
      return 1;
    }
    return this.args.weekends === false ? 5 : 7;
  }

  get viewType() {
    switch (this.args.view) {
      case "timeGridDay":
      case "timeGridWeek":
        return "time-grid";
      case "listYear":
        return "list";
      default:
        return "month";
    }
  }

  get isMonth() {
    return this.viewType === "month";
  }

  get isTimeGrid() {
    return this.viewType === "time-grid";
  }

  get isList() {
    return this.viewType === "list";
  }

  get style() {
    const declarations = [
      `--calendar-placeholder-columns: ${this.columnCount}`,
    ];
    const { height } = this.args;

    if (height && CSS.supports("height", height)) {
      declarations.push(`height: ${height}`);
    }

    return trustHTML(declarations.join("; "));
  }

  get columns() {
    return Array.from({ length: this.columnCount }, (_, index) => index);
  }

  get monthCells() {
    return Array.from(
      { length: MONTH_WEEKS * this.columnCount },
      (_, index) => ({
        events: Array.from({
          length: MONTH_EVENT_PATTERN[index % MONTH_EVENT_PATTERN.length],
        }),
      })
    );
  }

  get timeSlots() {
    return Array.from({ length: TIME_GRID_SLOTS }, (_, index) => index);
  }

  get timeGridColumns() {
    return this.columns.map((column) => ({
      events: TIME_GRID_EVENTS.filter((event) => event.column === column).map(
        positionStyle
      ),
    }));
  }

  get listGroups() {
    return LIST_GROUPS.map((count) => Array.from({ length: count }));
  }

  <template>
    <div
      aria-hidden="true"
      class="calendar-placeholder --{{this.viewType}}"
      style={{this.style}}
    >
      <div class="calendar-placeholder__toolbar">
        <div class="calendar-placeholder__toolbar-chunk">
          <DSkeleton
            class="calendar-placeholder__button"
            @variant="rect"
            @width="5.2em"
          />
          <DSkeleton
            class="calendar-placeholder__button --today"
            @variant="rect"
            @width="4.3em"
          />
        </div>
        <div class="calendar-placeholder__title">
          <DSkeleton @width="7em" />
        </div>
        <div class="calendar-placeholder__toolbar-chunk">
          <DSkeleton
            class="calendar-placeholder__button"
            @variant="rect"
            @width="15em"
          />
        </div>
      </div>

      {{#if this.isMonth}}
        <div class="calendar-placeholder__grid">
          {{#each this.columns}}
            <div class="calendar-placeholder__header-cell">
              <DSkeleton @width="2em" />
            </div>
          {{/each}}
          {{#each this.monthCells as |cell|}}
            <div class="calendar-placeholder__day">
              <DSkeleton
                class="calendar-placeholder__day-number"
                @width="1.25em"
              />
              {{#each cell.events}}
                <DSkeleton
                  class="calendar-placeholder__event"
                  @height="1.25em"
                  @variant="rect"
                />
              {{/each}}
            </div>
          {{/each}}
        </div>
      {{else if this.isTimeGrid}}
        <div class="calendar-placeholder__time-grid">
          <div class="calendar-placeholder__header-row">
            <div class="calendar-placeholder__gutter"></div>
            {{#each this.columns}}
              <div class="calendar-placeholder__header-cell">
                <DSkeleton @width="4em" />
              </div>
            {{/each}}
          </div>
          <div class="calendar-placeholder__body">
            <div class="calendar-placeholder__gutter">
              {{#each this.timeSlots}}
                <div class="calendar-placeholder__slot-label">
                  <DSkeleton @width="2.5em" />
                </div>
              {{/each}}
            </div>
            {{#each this.timeGridColumns as |column|}}
              <div class="calendar-placeholder__column">
                {{#each column.events as |style|}}
                  <div
                    class="calendar-placeholder__timed-event"
                    style={{style}}
                  >
                    <DSkeleton @height="100%" @variant="rect" @width="100%" />
                  </div>
                {{/each}}
              </div>
            {{/each}}
          </div>
        </div>
      {{else}}
        <div class="calendar-placeholder__list">
          {{#each this.listGroups as |rows|}}
            <div class="calendar-placeholder__list-heading">
              <DSkeleton @width="8em" />
              <DSkeleton @width="5em" />
            </div>
            {{#each rows}}
              <div class="calendar-placeholder__list-row">
                <DSkeleton @width="6em" />
                <DSkeleton @size="0.6em" @variant="circle" />
                <DSkeleton @width="40%" />
              </div>
            {{/each}}
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
