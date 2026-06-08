import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import I18n, { i18n } from "discourse-i18n";

const PRESET_PERIODS = ["last_7_days", "last_30_days", "last_3_months"];
const PERCENTAGE_KPIS = ["dau_mau"];

class MetricItem extends Component {
  get isPercentage() {
    return PERCENTAGE_KPIS.includes(this.args.metric.type);
  }

  get displayValue() {
    const value = this.args.metric.value;
    if (value == null) {
      return "—";
    }
    if (this.isPercentage) {
      return `${I18n.toNumber(value, { precision: 1 })}%`;
    }
    return I18n.toNumber(value, { precision: 0 });
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
    const value = this.args.metric.percent_change;
    const abs = Math.abs(value);

    if (abs > 0 && abs < 1) {
      const sign = value > 0 ? "+" : "-";
      return `${sign}${I18n.toNumber(abs, { precision: 1 })}%`;
    }

    const rounded = Math.round(value);
    const sign = rounded > 0 ? "+" : "";
    return `${sign}${I18n.toNumber(rounded, { precision: 0 })}%`;
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
