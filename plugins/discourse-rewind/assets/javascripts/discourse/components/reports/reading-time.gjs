import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";
import ditherImage from "discourse/plugins/discourse-rewind/discourse/modifiers/dither-image";

export default class ReadingTime extends Component {
  get coverUrl() {
    return getURL(
      `/plugins/discourse-rewind/images/books/${this.args.report.data.isbn}.jpg`
    );
  }

  get readTimeString() {
    let totalMinutes = Math.floor(this.args.report.data.reading_time / 60);
    let leftOverMinutes = totalMinutes % 60;
    let totalHours = (totalMinutes - leftOverMinutes) / 60;

    if (leftOverMinutes >= 35) {
      totalHours += 1;
      return `${totalHours}h`;
    } else {
      return `${totalHours}h ${leftOverMinutes}m`;
    }
  }

  get bookComparisonText() {
    return i18nForOwner(
      "discourse_rewind.reports.reading_time.book_comparison",
      this.args.isOwnRewind,
      {
        readingTime: this.readTimeString,
        bookTitle: this.args.report.data.book,
        username: this.args.user?.username,
      }
    );
  }

  <template>
    <div class="rewind-report-page --reading-time">
      <h2 class="rewind-report-title">
        {{i18n "discourse_rewind.reports.reading_time.title"}}
      </h2>
      <div class="rewind-reading">
        <p class="rewind-field">
          {{trustHTML this.bookComparisonText}}
        </p>
        <div class="rewind-reading__book">
          <div
            class="rewind-frame rewind-dither-frame"
            {{ditherImage this.coverUrl}}
          >
            <img alt="" src={{this.coverUrl}} />
          </div>
          {{#if @report.data.series}}
            <span aria-hidden="true" class="rewind-reading__volume"></span>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
