import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import {
  formatDeltaPercent,
  formatKpiValue,
  roundDeltaPercent,
} from "discourse/admin/lib/dashboard-format";
import { engagementHeadlineKeys } from "discourse/admin/lib/engagement-headline";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const PERCENTAGE_KPIS = ["dau_mau"];
const METRIC_ORDER = ["dau_mau", "daily_engaged_users", "new_signups"];

function direction(metric) {
  if (metric?.value == null) {
    return "unavailable";
  }

  if (metric.previous_value == null || metric.previous_value === 0) {
    return metric.value > 0 ? "improved" : "flat";
  }

  const change =
    metric.percent_change ??
    ((metric.value - metric.previous_value) / metric.previous_value) * 100;
  const roundedChange = roundDeltaPercent(change);

  if (roundedChange > 0) {
    return "improved";
  } else if (roundedChange < 0) {
    return "declined";
  }

  return "flat";
}

function percentChange(metric) {
  return (
    metric.percent_change ??
    ((metric.value - metric.previous_value) / metric.previous_value) * 100
  );
}

class MetricItem extends Component {
  get isPercentage() {
    return PERCENTAGE_KPIS.includes(this.args.metric.type);
  }

  get displayValue() {
    return formatKpiValue(this.args.metric.value, {
      percentage: this.isPercentage,
    });
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
          @model={{@metric.report_type}}
          @query={{@metric.report_query}}
          @route="adminReports.show"
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
          @icon="far-circle-question"
          @identifier={{concat "engagement-headline-" @metric.type "-tooltip"}}
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
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}

export default class EngagementHeadline extends Component {
  get headline() {
    const prefix = "admin.dashboard.sections.engagement.headline";
    const metricsByType = new Map(
      this.args.kpis.map((metric) => [metric.type, metric])
    );
    const metrics = METRIC_ORDER.map((type) => {
      const metric = metricsByType.get(type) ?? { type };
      return { ...metric, direction: direction(metric) };
    });
    const declined = metrics.filter(
      (metric) => metric.direction === "declined"
    );
    const ctaOwner = declined.reduce((most, metric) => {
      if (!most) {
        return metric;
      }
      return roundDeltaPercent(percentChange(metric)) <
        roundDeltaPercent(percentChange(most))
        ? metric
        : most;
    }, null)?.type;
    const directionsByType = Object.fromEntries(
      metrics.map((metric) => [metric.type, metric.direction])
    );
    const headlineKeys = engagementHeadlineKeys({
      stickiness: directionsByType.dau_mau,
      dailyEngagement: directionsByType.daily_engaged_users,
      newSignups: directionsByType.new_signups,
    });
    const summary = i18n(`${prefix}.summaries.${headlineKeys.summary}`);
    const cta = ctaOwner ? i18n(`${prefix}.cta.${ctaOwner}`) : null;

    return {
      title: i18n(`${prefix}.titles.${headlineKeys.title}`),
      summary: cta ? `${summary} ${cta}` : summary,
    };
  }

  <template>
    <div class="db-section__subheader">
      <div class="db-section__subintro">
        <h3>{{this.headline.title}}</h3>
        <p>{{this.headline.summary}}</p>
      </div>
      <div class="db-section__metrics">
        {{#each @kpis as |metric|}}
          <MetricItem @metric={{metric}} />
        {{/each}}
      </div>
    </div>
  </template>
}
