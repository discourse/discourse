import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";

export default class Reactions extends Component {
  get totalPostUsedReactions() {
    return Object.values(
      this.args.report.data.post_used_reactions ?? {}
    ).reduce((acc, count) => acc + count, 0);
  }

  get receivedReactions() {
    return this.args.report.data.post_received_reactions ?? {};
  }

  @action
  cleanEmoji(emojiName) {
    return emojiName.replaceAll(/_/g, " ");
  }

  @action
  computePercentage(count) {
    return `${((count / this.totalPostUsedReactions) * 100).toFixed(2)}%`;
  }

  @action
  computePercentageStyle(count) {
    return htmlSafe(`width: ${this.computePercentage(count)}`);
  }

  <template>
    <div class="rewind-report-page --post-received-reactions">
      <h2 class="rewind-report-title">
        {{i18n "discourse_rewind.reports.post_received_reactions.title"}}
      </h2>
      <div class="rewind-report-container">
        {{#each-in this.receivedReactions as |emojiName count|}}
          <div class="rewind-card scale">
            <span class="rewind-card__emoji">
              {{replaceEmoji (concat ":" emojiName ":")}}
            </span>
            <span class="rewind-card__data">{{count}}</span>
          </div>
        {{/each-in}}
      </div>
    </div>

    <div class="rewind-report-page --post-used-reactions">
      <h2 class="rewind-report-title">
        {{i18n "discourse_rewind.reports.post_used_reactions.title"}}
      </h2>
      <div class="rewind-card">
        <div class="rewind-reactions-chart">
          {{#each-in @report.data.post_used_reactions as |emojiName count|}}
            <div class="rewind-reactions-row">
              <span class="emoji">
                {{replaceEmoji (concat ":" emojiName ":")}}
              </span>
              <span class="percentage">{{this.computePercentage count}}</span>
              <div
                class="rewind-reactions-bar"
                style={{this.computePercentageStyle count}}
                title={{count}}
              ></div>
            </div>
          {{/each-in}}

          <span class="rewind-total-reactions">
            {{i18n
              "discourse_rewind.reports.post_used_reactions.total_number"
              count=this.totalPostUsedReactions
            }}
          </span>
        </div>
      </div>
    </div>
  </template>
}
