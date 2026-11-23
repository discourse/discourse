import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { barsFor } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-bars";

export default class Reactions extends Component {
  get received() {
    return barsFor(this.args.report.data.post_received_reactions);
  }

  get used() {
    const total = this.args.report.data.post_used_reactions_total;
    return barsFor(this.args.report.data.post_used_reactions).map((bar) => {
      const percentage = `${((bar.count / total) * 100).toFixed(2)}%`;
      return { ...bar, percentage, style: trustHTML(`width: ${percentage}`) };
    });
  }

  <template>
    <div class="rewind-report-page --reactions">

      <div class="rewind-reactions">
        {{#if this.received.length}}
          <section class="rewind-reactions__received">
            <h2 class="rewind-reactions__title">{{i18n
                "discourse_rewind.reports.post_received_reactions.title"
              }}</h2>
            <RewindWindow>
              {{#each this.received as |reaction|}}
                <div class="rewind-bar">
                  <span class="rewind-reactions__emoji">{{dEmoji
                      reaction.emoji
                    }}</span>
                  <span class="rewind-bar__track">
                    <span
                      class="rewind-bar__fill"
                      data-density={{reaction.density}}
                      style={{reaction.style}}
                    ></span>
                  </span>
                  <span class="rewind-bar__value">{{reaction.count}}</span>
                </div>
              {{/each}}
            </RewindWindow>
          </section>
        {{/if}}

        {{#if this.used.length}}
          <section class="rewind-reactions__used">
            <h2 class="rewind-reactions__title">{{i18n
                "discourse_rewind.reports.post_used_reactions.title"
              }}</h2>
            <RewindWindow>
              {{#each this.used as |reaction|}}
                <div class="rewind-bar">
                  <span class="rewind-reactions__emoji">{{dEmoji
                      reaction.emoji
                    }}</span>
                  <span class="rewind-bar__track">
                    <span
                      class="rewind-bar__fill"
                      data-density={{reaction.density}}
                      style={{reaction.style}}
                      title={{reaction.count}}
                    ></span>
                  </span>
                  <span class="rewind-bar__value">{{reaction.percentage}}</span>
                </div>
              {{/each}}
              <p class="rewind-reactions__total">{{i18n
                  "discourse_rewind.reports.post_used_reactions.total_number"
                  count=@report.data.post_used_reactions_total
                }}</p>
            </RewindWindow>
          </section>
        {{/if}}
      </div>
    </div>
  </template>
}
