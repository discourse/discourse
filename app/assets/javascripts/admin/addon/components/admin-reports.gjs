import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";

export default class AdminReports extends Component {
  @service siteSettings;

  @tracked reports;
  @tracked filter = "";

  @bind
  async loadReports() {
    const response = await ajax("/admin/reports");
    return response.reports;
  }

  @bind
  filterReports(reports, filter) {
    if (!reports) {
      return [];
    }

    let filteredReports = reports;
    if (filter) {
      const lowerCaseFilter = filter.toLowerCase();
      filteredReports = filteredReports.filter((report) => {
        return (
          (report.title || "").toLowerCase().includes(lowerCaseFilter) ||
          (report.description || "").toLowerCase().includes(lowerCaseFilter)
        );
      });
    }

    const hiddenReports = (this.siteSettings.dashboard_hidden_reports || "")
      .split("|")
      .filter(Boolean);
    filteredReports = filteredReports.filter(
      (report) => !hiddenReports.includes(report.type)
    );

    return filteredReports;
  }

  <template>
    <AsyncContent @asyncData={{this.loadReports}}>
      <:content as |reports|>
        <div class="d-admin-filter admin-reports-header">
          <div class="admin-filter__input-container">
            <input
              type="text"
              class="admin-filter__input admin-reports-header__filter"
              placeholder={{i18n "admin.filter_reports"}}
              value={{this.filter}}
              {{on "input" (withEventValue (fn (mut this.filter)))}}
            />
          </div>
        </div>
        <AdminSectionLandingWrapper class="admin-reports-list">
          {{#each (this.filterReports reports this.filter) as |report|}}
            <AdminSectionLandingItem
              @titleLabelTranslated={{report.title}}
              @descriptionLabelTranslated={{report.description}}
              @titleRoute="adminReports.show"
              @titleRouteModel={{report.type}}
            />
          {{/each}}
        </AdminSectionLandingWrapper>
      </:content>
    </AsyncContent>
  </template>
}
