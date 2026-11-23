import Component from "@glimmer/component";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import RewindWindow from "discourse/plugins/discourse-rewind/discourse/components/rewind-window";
import { barsFor } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-bars";

const RankedBars = <template>
  <section class="rewind-ai__list">
    <h3 class="rewind-ai__heading">{{@title}}</h3>
    {{#each @entries as |entry|}}
      <div class="rewind-bar">
        <span class="rewind-ai__name">{{entry.label}}</span>
        <span class="rewind-bar__track">
          <span
            class="rewind-bar__fill"
            data-density={{entry.density}}
            style={{entry.style}}
          ></span>
        </span>
        <span class="rewind-bar__value">{{entry.count}}</span>
      </div>
    {{/each}}
  </section>
</template>;

export default class AiUsage extends Component {
  get features() {
    return barsFor(
      this.args.report.data.feature_usage.map((entry) => ({
        ...entry,
        label: entry.name.replace(/_/g, " "),
      }))
    );
  }

  get models() {
    return barsFor(
      this.args.report.data.model_usage.map((entry) => ({
        ...entry,
        label: entry.name,
      }))
    );
  }

  <template>
    <div class="rewind-report-page --ai-usage">
      <h2 class="rewind-report-title">{{i18n
          "discourse_rewind.reports.ai_usage.system_title"
        }}</h2>
      <p class="rewind-report-page__lede">{{i18n
          "discourse_rewind.reports.ai_usage.wake_up"
          username=@user.username
        }}</p>

      <div class="rewind-ai">
        <RewindWindow class="rewind-ai__calculator">
          <p class="rewind-ai__display">
            <span class="rewind-ai__number">{{dNumber
                @report.data.total_requests
              }}</span>
            <span class="rewind-ai__unit">{{i18n
                "discourse_rewind.reports.ai_usage.total_requests"
              }}</span>
          </p>
          <dl class="rewind-ai__registers">
            <div>
              <dt>{{i18n "discourse_rewind.reports.ai_usage.total_tokens"}}</dt>
              <dd>{{dNumber @report.data.total_tokens}}</dd>
            </div>
            <div>
              <dt>{{i18n "discourse_rewind.reports.ai_usage.success_rate"}}</dt>
              <dd>{{@report.data.success_rate}}%</dd>
            </div>
          </dl>
        </RewindWindow>

        <div class="rewind-ai__lists">
          {{#if this.features.length}}
            <RankedBars
              @entries={{this.features}}
              @title={{i18n
                "discourse_rewind.reports.ai_usage.section_features"
              }}
            />
          {{/if}}
          {{#if this.models.length}}
            <RankedBars
              @entries={{this.models}}
              @title={{i18n "discourse_rewind.reports.ai_usage.section_models"}}
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
