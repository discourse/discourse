import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { ajax } from "discourse/lib/ajax";
import dIcon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class AdminReports extends Component {
  @service siteSettings;
  @tracked reports = null;
  @tracked filter = "";
  @tracked isLoading = false;

  @bind
  loadReports() {
    this.isLoading = true;
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
    <div {{didInsert this.loadReports}}>
      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        <div class="admin-reports-header">
          <h2>{{i18n "admin.reports.title"}}</h2>
          <Input
            class="admin-reports-header__filter"
            placeholder={{i18n "admin.filter_reports"}}
            @value={{this.filter}}
          />
        </div>

        <div class="alert alert-info">
          {{dIcon "book"}}
          {{htmlSafe (i18n "admin.reports.meta_doc")}}
        </div>

        <ul class="admin-reports-list">
          {{#each this.filteredReports as |report|}}
            <li class="admin-reports-list__report">
              <LinkTo @route="adminReports.show" @model={{report.type}}>
                <h3
                  class="admin-reports-list__report-title"
                >{{report.title}}</h3>
                {{#if report.description}}
                  <p class="admin-reports-list__report-description">
                    {{report.description}}
                  </p>
                {{/if}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
