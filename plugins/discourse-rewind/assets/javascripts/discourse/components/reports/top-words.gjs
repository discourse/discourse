import { i18n } from "discourse-i18n";
import WordCard from "discourse/plugins/discourse-rewind/discourse/components/reports/top-words/word-card";

export default <template>
  <div class="rewind-report-page --top-words">
    <h2 class="rewind-report-title">{{i18n
        "discourse_rewind.reports.top_words.title"
      }}</h2>
    <ol class="rewind-words">
      {{#each @report.data as |entry index|}}
        <li class="rewind-words__slot">
          <WordCard
            @count={{entry.score}}
            @index={{index}}
            @word={{entry.word}}
          />
        </li>
      {{/each}}
    </ol>
  </div>
</template>
