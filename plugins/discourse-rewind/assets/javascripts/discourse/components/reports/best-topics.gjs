import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class BestTopics extends Component {
  rankClass(idx) {
    return `rank-${idx + 1}`;
  }

  <template>
    {{#if @report.data.length}}
      <div class="rewind-report-page --best-topics">
        <h2 class="rewind-report-title">
          {{i18n
            "discourse_rewind.reports.best_topics.title"
            count=@report.data.length
          }}
        </h2>
        <div class="rewind-report-container">
          <div class="rewind-card">
            {{#each @report.data as |topic idx|}}
              <a
                href={{getURL (concat "/t/-/" topic.topic_id)}}
                class={{concatClass "best-topics__topic" (this.rankClass idx)}}
              >
                <span class="best-topics --rank"></span>
                <span class="best-topics --rank"></span>
                <h2 class="best-topics__header">{{topic.title}}</h2>
                <span class="best-topics__excerpt">
                  {{replaceEmoji (htmlSafe topic.excerpt)}}
                </span>
              </a>
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
