import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import {
  formatDashboardHeadlinePeriod,
  formatDeltaPercent,
  formatKpiValue,
  roundDeltaPercent,
} from "discourse/admin/lib/dashboard-format";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const PRESET_PERIODS = ["last_7_days", "last_30_days", "last_3_months"];
const PERCENTAGE_KPIS = ["dau_mau"];
const METRIC_NAMES = {
  dau_mau: "stickiness",
  daily_engaged_users: "daily_engagement",
  new_signups: "new_signups",
};
const METRIC_ORDER = ["dau_mau", "daily_engaged_users", "new_signups"];

function direction(metric) {
  if (metric.value == null) {
    return null;
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

function metricGroup(metrics) {
  return i18n(
    `admin.dashboard.sections.engagement.headline.metric_groups.${metrics
      .map((metric) => METRIC_NAMES[metric.type])
      .join("_")}`
  );
}

function lowercaseMetricGroup(metrics) {
  return i18n(
    `admin.dashboard.sections.engagement.headline.metric_groups_lowercase.${metrics
      .map((metric) => METRIC_NAMES[metric.type])
      .join("_")}`
  );
}

function metricCount(metrics) {
  return metrics.length === 1 && metrics[0].type !== "new_signups" ? 1 : 2;
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
  get headline() {
    const prefix = "admin.dashboard.sections.engagement.headline";
    const metrics = [...this.args.kpis]
      .sort(
        (left, right) =>
          METRIC_ORDER.indexOf(left.type) - METRIC_ORDER.indexOf(right.type)
      )
      .map((metric) => ({ ...metric, direction: direction(metric) }))
      .filter((metric) => metric.direction);

    if (metrics.length === 0) {
      return {
        title: i18n(`${prefix}.no_data.title`),
        summary: i18n(`${prefix}.no_data.summary`),
      };
    }

    const improved = metrics.filter(
      (metric) => metric.direction === "improved"
    );
    const declined = metrics.filter(
      (metric) => metric.direction === "declined"
    );
    const flat = metrics.filter((metric) => metric.direction === "flat");
    const period = formatDashboardHeadlinePeriod(this.args.period);

    if (improved.length === metrics.length && metrics.length === 3) {
      return {
        title: i18n(`${prefix}.all_improved.title`, { period }),
        summary: i18n(`${prefix}.all_improved.summary`),
      };
    }

    if (improved.length > 0 && declined.length === 0) {
      const improvedMetrics = metricGroup(improved);
      if (flat.length === 0) {
        return {
          title: i18n(`${prefix}.improved_only.title`, {
            count: metricCount(improved),
            metrics: improvedMetrics,
            period,
          }),
          summary: i18n(`${prefix}.improved_only.summary`, {
            count: metricCount(improved),
            metrics: improvedMetrics,
          }),
        };
      }
      return {
        title: i18n(`${prefix}.improved_flat.title`, {
          count: metricCount(improved),
          metrics: improvedMetrics,
          period,
        }),
        summary: i18n(
          `${prefix}.improved_flat.${
            metricCount(improved) === 1 ? "one" : "many"
          }_improved.summary`,
          {
            count: metricCount(flat),
            improved_metrics: improvedMetrics,
            flat_metrics: lowercaseMetricGroup(flat),
          }
        ),
      };
    }

    const ctaOwner = declined.reduce((most, metric) => {
      if (!most) {
        return metric;
      }
      return roundDeltaPercent(percentChange(metric)) <
        roundDeltaPercent(percentChange(most))
        ? metric
        : most;
    }, null)?.type;

    if (improved.length > 0) {
      const improvedMetrics = metricGroup(improved);
      return {
        title: i18n(`${prefix}.mixed_decline.title`, {
          count: metricCount(improved),
          metrics: improvedMetrics,
          period,
        }),
        summary: i18n(
          `${prefix}.mixed_decline.${ctaOwner}.${
            metricCount(improved) === 1 ? "one" : "many"
          }_improved.summary`,
          {
            count: metricCount(declined),
            improved_metrics: improvedMetrics,
            declined_metrics: lowercaseMetricGroup(declined),
          }
        ),
      };
    }

    if (declined.length === metrics.length && metrics.length === 3) {
      return {
        title: i18n(`${prefix}.all_declined.title`, { period }),
        summary: i18n(`${prefix}.all_declined.${ctaOwner}.summary`),
      };
    }

    if (declined.length > 0) {
      if (flat.length === 0) {
        return {
          title: i18n(`${prefix}.declined_only.title`, { period }),
          summary: i18n(`${prefix}.declined_only.${ctaOwner}.summary`, {
            count: metricCount(declined),
            metrics: metricGroup(declined),
          }),
        };
      }
      return {
        title: i18n(`${prefix}.declined_flat.title`, { period }),
        summary: i18n(
          `${prefix}.declined_flat.${ctaOwner}.${
            metricCount(declined) === 1 ? "one" : "many"
          }_declined.summary`,
          {
            count: metricCount(flat),
            declined_metrics: metricGroup(declined),
            flat_metrics: lowercaseMetricGroup(flat),
          }
        ),
      };
    }

    if (metrics.length === 3) {
      return {
        title: i18n(`${prefix}.all_flat.title`, { period }),
        summary: i18n(`${prefix}.all_flat.summary`),
      };
    }

    return {
      title: i18n(`${prefix}.flat_only.title`, { period }),
      summary: i18n(`${prefix}.flat_only.summary`, {
        count: metricCount(flat),
        metrics: metricGroup(flat),
      }),
    };
  }

  get comparisonLabel() {
    const key = PRESET_PERIODS.includes(this.args.period)
      ? this.args.period
      : "previous_period";
    return i18n(`admin.dashboard.highlights.comparison.${key}`);
  }

  <template>
    <div class="db-section__subheader">
      {{#if this.headline}}
        <div class="db-section__subintro">
          <h3>{{this.headline.title}}</h3>
          <p>{{this.headline.summary}}</p>
        </div>
      {{/if}}
      <div class="db-section__metrics">
        {{#each @kpis as |metric|}}
          <MetricItem
            @metric={{metric}}
            @comparisonLabel={{this.comparisonLabel}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
