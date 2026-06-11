import Component from "@glimmer/component";
import KpiTile from "discourse/admin/components/dashboard/kpi-tile";
import DashboardSection from "discourse/admin/components/dashboard/section";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

const PRESET_PERIODS = ["last_7_days", "last_30_days", "last_3_months"];

export default class Highlights extends Component {
  get comparisonLabel() {
    const key = PRESET_PERIODS.includes(this.args.period)
      ? this.args.period
      : "previous_period";
    return i18n(`admin.dashboard.highlights.comparison.${key}`);
  }

  get hasKpis() {
    return this.args.highlights?.kpis?.length > 0;
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.highlights.title"}}
      @layout="row"
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
    >
      <:intro>
        <PluginOutlet
          @name="admin-dashboard-highlights-before-kpis"
          @outletArgs={{lazyHash
            period=@period
            startDate=@startDate
            endDate=@endDate
            kpis=@highlights.kpis
          }}
        />
      </:intro>
      <:default>
        {{#if @fetchError}}
          <div class="db-highlights__error" role="alert">
            {{i18n "admin.dashboard.highlights.fetch_error"}}
          </div>
        {{else}}
          {{#each @highlights.kpis as |kpi|}}
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
        {{/if}}
      </:default>
    </DashboardSection>
  </template>
}
