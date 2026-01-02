import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class BestTopics extends Component {
  rankClass(idx) {
    return `rank-${idx + 1}`;
  }

  get titleText() {
    return i18nForOwner(
      "discourse_rewind.reports.best_topics.title",
      this.args.isOwnRewind,
      {
        count: this.args.report.data.length,
        username: this.args.user?.username,
      }
    );
  }

  <template>
    {{#if @report.data.length}}
      <div class="rewind-report-page --best-topics">
        <h2 class="rewind-report-title">
          {{this.titleText}}
        </h2>
        <div class="rewind-report-container">
          <div class="rewind-card">
            {{#each @report.data as |topic idx|}}
              <div
                class={{concatClass "best-topics__topic" (this.rankClass idx)}}
              >
                <span class="best-topics --rank"></span>
                <span class="best-topics --rank"></span>
                <h2 class="best-topics__header">{{replaceEmoji
                    topic.title
                  }}</h2>
                <span class="best-topics__excerpt">
                  {{replaceEmoji (htmlSafe topic.excerpt)}}
                </span>

                <div class="best-topics__metadata">
                  <a href={{getURL (concat "/t/-/" topic.topic_id)}}>
                    {{i18n "discourse_rewind.reports.best_topics.view_topic"}}
                  </a>
                </div>
              </div>
            {{/each}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
