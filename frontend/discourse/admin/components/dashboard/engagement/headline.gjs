import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import {
  formatDeltaPercent,
  formatKpiValue,
} from "discourse/admin/lib/dashboard-format";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const PRESET_PERIODS = ["last_7_days", "last_30_days", "last_3_months"];

class MetricItem extends Component {
  get displayValue() {
    return formatKpiValue(this.args.metric.type, this.args.metric.value);
  }

  get hasDelta() {
    return this.args.metric.percent_change != null;
  }

  get deltaClass() {
    const change = this.args.metric.percent_change;
    if (change > 0) {
      return "--pos";
    } else if (change < 0) {
      return "--neg";
    }
    return "--neutral";
  }

  get deltaText() {
    return formatDeltaPercent(this.args.metric.percent_change);
  }

  <template>
    <div class="db-section__metric">
      <div class="db-section__metric-number">{{this.displayValue}}</div>
      <div class="db-section__metric-label">
        <LinkTo
          @route="adminReports.show"
          @model={{@metric.report_type}}
          @query={{@metric.report_query}}
        >
          {{i18n
            (concat
              "admin.dashboard.sections.engagement.headline.metrics."
              @metric.type
            )
          }}
        </LinkTo>
        <DTooltip
          class="db-section__info"
          @identifier={{concat "engagement-headline-" @metric.type "-tooltip"}}
          @icon="far-circle-question"
        >
          <:content>
            {{i18n
              (concat "admin.dashboard.highlights.kpi." @metric.type ".tooltip")
            }}
          </:content>
        </DTooltip>
      </div>
      {{#if this.hasDelta}}
        {{#if (eq this.deltaClass "--neutral")}}
          <span class="db-pill">{{i18n "admin.dashboard.stable"}}</span>
        {{else}}
          <div class={{concat "db-delta " this.deltaClass}}>
            {{this.deltaText}}
            <span class="db-delta__label">{{@comparisonLabel}}</span>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}

export default class EngagementHeadline extends Component {
  get titleKey() {
    return `${this.args.headline.key}.title`;
  }

  get summaryKey() {
    return `${this.args.headline.key}.summary`;
  }

  get comparisonLabel() {
    const key = PRESET_PERIODS.includes(this.args.period)
      ? this.args.period
      : "previous_period";
    return i18n(`admin.dashboard.highlights.comparison.${key}`);
  }

  <template>
    <div class="db-section__subheader">
      <div class="db-section__subintro">
        <h3>{{i18n this.titleKey}}</h3>
        <p>{{i18n this.summaryKey}}</p>
      </div>
      <div class="db-section__metrics">
        {{#each @kpis as |metric|}}
          <MetricItem @metric={{metric}} />
        {{/each}}
      </div>
    </div>
  </template>
}
