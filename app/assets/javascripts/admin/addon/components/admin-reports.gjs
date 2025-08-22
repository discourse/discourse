import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";

export default class AdminReports extends Component {
  @service siteSettings;

  @bind
  async loadReports() {
    const response = await ajax("/admin/reports");
    return response.reports;
  }

  @bind
  filterReports(reports) {
    if (!reports) {
      return [];
    }

    const hiddenReports = (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
    return reports.filter((report) => !hiddenReports.includes(report.type));
  }

  <template>
    <AsyncContent @asyncData={{this.loadReports}}>
      <:content as |reports|>
        <AdminFilterControls
          @array={{this.filterReports reports}}
          @searchableProps={{array "title" "description"}}
          @inputPlaceholder={{i18n "admin.filter_reports"}}
          @noResultsMessage={{i18n "admin.filter_reports_no_results"}}
        >
          <:content as |filteredReports|>
            <AdminSectionLandingWrapper class="admin-reports-list">
              {{#each filteredReports as |report|}}
                <AdminSectionLandingItem
                  @titleLabelTranslated={{report.title}}
                  @descriptionLabelTranslated={{report.description}}
                  @titleRoute="adminReports.show"
                  @titleRouteModel={{report.type}}
                />
              {{/each}}
            </AdminSectionLandingWrapper>
          </:content>
        </AdminFilterControls>
      </:content>
    </AsyncContent>
  </template>
}
