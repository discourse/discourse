import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import getURL from "discourse/lib/get-url";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class BestTopics extends Component {
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

  rank(index) {
    return index + 1;
  }

  <template>
    <div class="rewind-report-page --best-topics">
      <h2 class="rewind-report-title">{{this.titleText}}</h2>
      <ol class="rewind-topics">
        {{#each @report.data as |topic index|}}
          <li>
            <RewindWindow class="rewind-topics__topic">
              <span
                aria-hidden="true"
                class="rewind-medal --rank-{{this.rank index}}"
              ></span>
              <h3 class="rewind-topics__title">{{dReplaceEmoji
                  topic.title
                }}</h3>
              <div class="rewind-field">
                {{dReplaceEmoji (trustHTML topic.excerpt)}}
              </div>
              <a
                class="rewind-link-btn"
                href={{getURL (concat "/t/-/" topic.topic_id)}}
              >
                {{i18n "discourse_rewind.reports.best_topics.view_topic"}}
              </a>
            </RewindWindow>
          </li>
        {{/each}}
      </ol>
    </div>
  </template>
}
