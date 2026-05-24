import Component from "@glimmer/component";
import KpiTile from "discourse/admin/components/dashboard/kpi-tile";
import { i18n } from "discourse-i18n";

const PRESET_PERIODS = ["last_7_days", "last_30_days", "last_3_months"];

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
    <div class="db-section__subheader db-engagement-headline">
      <div class="db-section__subintro">
        <h3>{{i18n this.titleKey}}</h3>
        <p>{{i18n this.summaryKey}}</p>
      </div>
      <div class="db-section__metrics">
        {{#each @kpis as |kpi|}}
          <KpiTile
            @type={{kpi.type}}
            @value={{kpi.value}}
            @previousValue={{kpi.previous_value}}
            @percentChange={{kpi.percent_change}}
            @reportType={{kpi.report_type}}
            @reportQuery={{kpi.report_query}}
            @comparisonLabel={{this.comparisonLabel}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
