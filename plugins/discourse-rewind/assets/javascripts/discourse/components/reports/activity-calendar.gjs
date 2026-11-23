import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const ROWS = 7;
const MONTH_SPANS = [
  [5, 4, 4, 5],
  [4, 4, 5, 4],
  [5, 4, 4, 5],
];
const MEDIUM_MIN_POSTS = 10;
const HIGH_MIN_POSTS = 20;

export default class ActivityCalendar extends Component {
  get legend() {
    const rangeKey = "discourse_rewind.reports.activity_calendar.legend.range";

    return [
      {
        modifier: "--empty",
        label: i18n(
          "discourse_rewind.reports.activity_calendar.legend.no_posts"
        ),
      },
      {
        modifier: "--low",
        label: i18n(rangeKey, { min: 1, max: MEDIUM_MIN_POSTS - 1 }),
      },
      {
        modifier: "--medium",
        label: i18n(rangeKey, {
          min: MEDIUM_MIN_POSTS,
          max: HIGH_MIN_POSTS - 1,
        }),
      },
      {
        modifier: "--high",
        label: i18n(
          "discourse_rewind.reports.activity_calendar.legend.and_up",
          {
            min: HIGH_MIN_POSTS,
          }
        ),
      },
    ];
  }

  get sections() {
    const data = this.args.report.data;
    let firstColumn = 0;
    let monthIndex = 0;

    return MONTH_SPANS.map((spans) => {
      const columns = spans.reduce((total, span) => total + span, 0);
      const months = spans.map((span) => ({
        span,
        label: moment().month(monthIndex++).format("MMM"),
      }));
      const rows = Array.from({ length: ROWS }, (_row, row) =>
        Array.from(
          { length: columns },
          (_column, column) => data[(firstColumn + column) * ROWS + row]
        )
      );
      firstColumn += columns;

      return {
        months,
        rows,
        style: trustHTML(`--rewind-calendar-weeks: ${columns}`),
      };
    });
  }

  @action
  computeCellTitle(cell) {
    if (!cell || !cell.date) {
      return "";
    }

    const date = moment(cell.date).format("LL");
    const username = this.args.user?.username;

    if (cell.visited && cell.post_count === 0) {
      return i18nForOwner(
        "discourse_rewind.reports.activity_calendar.cell_title.visited_no_posts",
        this.args.isOwnRewind,
        { date, username }
      );
    } else if (cell.post_count > 0) {
      return i18nForOwner(
        "discourse_rewind.reports.activity_calendar.cell_title.visited_with_posts",
        this.args.isOwnRewind,
        { date, count: cell.post_count, username }
      );
    }

    return i18nForOwner(
      "discourse_rewind.reports.activity_calendar.cell_title.no_activity",
      this.args.isOwnRewind,
      { date, username }
    );
  }

  @action
  computeClass(count) {
    if (!count) {
      return "--empty";
    } else if (count < MEDIUM_MIN_POSTS) {
      return "--low";
    } else if (count < HIGH_MIN_POSTS) {
      return "--medium";
    } else {
      return "--high";
    }
  }

  <template>
    <div class="rewind-report-page --activity-calendar">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.activity_calendar.title"
        }}</h2>

      <RewindWindow>
        <div class="rewind-calendar">
          {{#each this.sections as |section|}}
            <div class="rewind-calendar__section" style={{section.style}}>
              <table class="rewind-calendar__grid">
                <thead>
                  <tr>
                    {{#each section.months as |month|}}
                      <th
                        class="rewind-calendar__month"
                        colspan={{month.span}}
                      >{{month.label}}</th>
                    {{/each}}
                  </tr>
                </thead>
                <tbody>
                  {{#each section.rows as |row|}}
                    <tr>
                      {{#each row as |cell|}}
                        <td
                          class={{dConcatClass
                            "rewind-calendar-cell"
                            (this.computeClass cell.post_count)
                          }}
                          data-date={{cell.date}}
                          title={{this.computeCellTitle cell}}
                        ></td>
                      {{/each}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </div>
          {{/each}}
        </div>

        <ul class="rewind-calendar-legend">
          {{#each this.legend as |item|}}
            <li class="rewind-calendar-legend__item">
              <span
                aria-hidden="true"
                class={{dConcatClass
                  "rewind-calendar-cell rewind-calendar-legend__swatch"
                  item.modifier
                }}
              ></span>
              {{item.label}}
            </li>
          {{/each}}
        </ul>
      </RewindWindow>
    </div>
  </template>
}
