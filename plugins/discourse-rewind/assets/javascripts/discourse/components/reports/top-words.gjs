import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import WordCard from "discourse/plugins/discourse-rewind/discourse/components/reports/top-words/word-card";

export default class WordCards extends Component {
  get topWords() {
    return this.args.report.data.sort((a, b) => b.score - a.score).slice(0, 5);
  }

  <template>
    <div class="rewind-report-page --top-words">
      <div class="rewind-report-container">
        <h2 class="rewind-report-title">{{i18n
            "discourse_rewind.reports.top_words.title"
          }}</h2>
        <div class="cards-container">
          {{#each this.topWords as |entry index|}}
            <WordCard
              @word={{entry.word}}
              @count={{entry.score}}
              @index={{index}}
            />
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
