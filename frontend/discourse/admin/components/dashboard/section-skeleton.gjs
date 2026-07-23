import Component from "@glimmer/component";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const KPIS = Array.from({ length: 4 });
const REPORT_CARDS = Array.from({ length: 4 });
const ROWS = Array.from({ length: 5 });

export default class DashboardSectionSkeleton extends Component {
  get title() {
    return i18n(`admin.dashboard.sections.${this.args.id}.title`);
  }

  get loadingLabel() {
    return i18n("admin.dashboard.loading_section", { section: this.title });
  }

  <template>
    <DashboardSection @title={{this.title}} ...attributes>
      <div
        class="db-skeleton --animation"
        role="status"
        aria-label={{this.loadingLabel}}
      >
        {{#if (eq @id "highlights")}}
          <div class="db-skeleton__kpi-row">
            {{#each KPIS}}
              <div class="db-skeleton__kpi">
                <div class="db-skeleton__kpi-value"></div>
                <div class="db-skeleton__kpi-label"></div>
                <div class="db-skeleton__kpi-delta"></div>
              </div>
            {{/each}}
          </div>
        {{else if (eq @id "reports")}}
          <div class="db-skeleton__report-grid">
            {{#each REPORT_CARDS}}
              <div class="db-skeleton__report-card">
                <div class="db-skeleton__report-card-header">
                  <div class="db-skeleton__report-card-title"></div>
                  <div class="db-skeleton__report-card-label"></div>
                </div>
                <div class="db-skeleton__report-card-chart"></div>
              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="db-skeleton__section-wrapper">
            <div class="db-skeleton__subheader">
              <div class="db-skeleton__subintro">
                <div class="db-skeleton__heading-line"></div>
                <div class="db-skeleton__text-line"></div>
                <div class="db-skeleton__text-line --short"></div>
              </div>
            </div>
            <div class="db-skeleton__chart"></div>
            <ul class="db-skeleton__list">
              {{#each ROWS}}
                <li class="db-skeleton__list-row">
                  <span class="db-skeleton__list-name"></span>
                  <span class="db-skeleton__list-value"></span>
                </li>
              {{/each}}
            </ul>
          </div>
        {{/if}}
      </div>
    </DashboardSection>
  </template>
}
