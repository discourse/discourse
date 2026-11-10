import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

export default class Reactions extends Component {
  @action
  computePercentage(count) {
    const total = this.args.report.data.post_used_reactions_total;
    return `${((count / total) * 100).toFixed(2)}%`;
  }

  @action
  computePercentageStyle(count) {
    return trustHTML(`width: ${this.computePercentage(count)}`);
  }

  <template>
    {{#if @report.data.post_received_reactions.length}}
      <div class="rewind-report-page --post-received-reactions">
        <h2 class="rewind-report-title">
          {{i18n "discourse_rewind.reports.post_received_reactions.title"}}
        </h2>
        <div class="rewind-report-container">
          {{#each @report.data.post_received_reactions as |reaction|}}
            <div class="rewind-card scale">
              <span class="rewind-card__emoji">
                {{dEmoji reaction.emoji}}
              </span>
              <span class="rewind-card__data">{{reaction.count}}</span>
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}

    {{#if @report.data.post_used_reactions.length}}
      <div class="rewind-report-page --post-used-reactions">
        <h2 class="rewind-report-title">
          {{i18n "discourse_rewind.reports.post_used_reactions.title"}}
        </h2>
        <div class="rewind-card">
          <div class="rewind-reactions-chart">
            {{#each @report.data.post_used_reactions as |reaction|}}
              <div class="rewind-reactions-row">
                <span class="emoji">
                  {{dEmoji reaction.emoji}}
                </span>
                <span class="percentage">{{this.computePercentage
                    reaction.count
                  }}</span>
                <div
                  class="rewind-reactions-bar"
                  style={{this.computePercentageStyle reaction.count}}
                  title={{reaction.count}}
                ></div>
              </div>
            {{/each}}

            <span class="rewind-total-reactions">
              {{i18n
                "discourse_rewind.reports.post_used_reactions.total_number"
                count=@report.data.post_used_reactions_total
              }}
            </span>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
