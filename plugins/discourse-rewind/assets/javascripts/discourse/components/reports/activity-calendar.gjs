import Component from "@glimmer/component";
import { action } from "@ember/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const ROWS = 7;
const COLS = 53;

export default class ActivityCalendar extends Component {
  get rowsArray() {
    const data = this.args.report.data;
    let rowsArray = [];

    for (let r = 0; r < ROWS; r++) {
      let rowData = [];
      for (let c = 0; c < COLS; c++) {
        const index = c * ROWS + r;
        rowData.push(data[index] ? data[index] : "");
      }
      rowsArray.push(rowData);
    }

    return rowsArray;
  }

  @action
  getAbbreviatedMonth(monthIndex) {
    return moment().month(monthIndex).format("MMM");
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
    } else if (count < 10) {
      return "--low";
    } else if (count < 20) {
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

      <div class="rewind-card">
        <table class="rewind-calendar">
          <thead>
            <tr>
              <td
                class="activity-header-cell"
                colspan="5"
              >{{this.getAbbreviatedMonth 0}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 1}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 2}}</td>
              <td
                class="activity-header-cell"
                colspan="5"
              >{{this.getAbbreviatedMonth 3}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 4}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 5}}</td>
              <td
                class="activity-header-cell"
                colspan="5"
              >{{this.getAbbreviatedMonth 6}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 7}}</td>
              <td
                class="activity-header-cell"
                colspan="5"
              >{{this.getAbbreviatedMonth 8}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 9}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 10}}</td>
              <td
                class="activity-header-cell"
                colspan="4"
              >{{this.getAbbreviatedMonth 11}}</td>
            </tr>
          </thead>
          <tbody>
            {{#each this.rowsArray as |row|}}
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
    </div>
  </template>
}
