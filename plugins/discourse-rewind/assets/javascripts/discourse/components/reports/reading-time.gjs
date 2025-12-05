import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class ReadingTime extends Component {
  get readTimeString() {
    let totalMinutes = Math.floor(this.args.report.data.reading_time / 60);
    let leftOverMinutes = totalMinutes % 60;
    let totalHours = (totalMinutes - leftOverMinutes) / 60;

    if (leftOverMinutes >= 35) {
      totalHours += 1;
      leftOverMinutes = 0;
      return `${totalHours}h`;
    } else {
      return `${totalHours}h ${leftOverMinutes}m`;
    }
  }

  <template>
    {{#if @report.data}}
      <div class="rewind-report-page --reading-time">
        <h2 class="rewind-report-title">
          {{i18n "discourse_rewind.reports.reading_time.title"}}
        </h2>
        <div class="rewind-card">
          <p class="reading-time__text">
            {{htmlSafe
              (i18n
                "discourse_rewind.reports.reading_time.book_comparison"
                readingTitme=this.readTimeString
                bookTitle=@report.data.book
              )
            }}
          </p>
          <div class="reading-time__book">
            <div class="book">
              <img
                alt=""
                src="/plugins/discourse-rewind/images/books/{{@report.data.isbn}}.jpg"
              />
            </div>
            {{#if @report.data.series}}
              <div class="book-series one"></div>
              <div class="book-series two"></div>
              <div class="book-series three"></div>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
