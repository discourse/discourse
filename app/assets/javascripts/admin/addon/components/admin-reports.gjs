import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";

export default class AdminReports extends Component {
  @service siteSettings;
  @tracked reports = null;
  @tracked filter = "";
  @tracked isLoading = true;

  constructor() {
    super(...arguments);
    this.loadReports();
  }

  @bind
  loadReports() {
    ajax("/admin/reports")
      .then((json) => {
        this.reports = json.reports;
      })
      .finally(() => (this.isLoading = false));
  }

  get filteredReports() {
    if (!this.reports) {
      return [];
    }

    let filteredReports = this.reports;
    if (this.filter) {
      const lowerCaseFilter = this.filter.toLowerCase();
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
    <ConditionalLoadingSpinner @condition={{this.isLoading}}>
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
        {{#each this.filteredReports as |report|}}
          <AdminSectionLandingItem
            @titleLabelTranslated={{report.title}}
            @descriptionLabelTranslated={{report.description}}
            @titleRoute="adminReports.show"
            @titleRouteModel={{report.type}}
          />
        {{/each}}
      </AdminSectionLandingWrapper>
    </ConditionalLoadingSpinner>
  </template>
}
