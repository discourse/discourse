import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.reportingImprovements}}
    {{#if @controller.showHeader}}
      <DPageHeader
        @titleLabel={{i18n "admin.config.reports.title"}}
        @descriptionLabel={{i18n "admin.config.reports.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/240233"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/reports"
            @label={{i18n "admin.config.reports.title"}}
          />
        </:breadcrumbs>
      </DPageHeader>
    {{/if}}
  {{else}}
    {{#if @controller.showHeader}}
      <DPageHeader
        @titleLabel={{i18n "admin.config.reports.title"}}
        @descriptionLabel={{i18n "admin.config.reports.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/-/240233"
        @hideTabs={{@controller.hideTabs}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/reports"
            @label={{i18n "admin.config.reports.title"}}
          />
        </:breadcrumbs>
        <:tabs>
          <DNavItem
            @route="adminReports.dashboardSettings"
            @label="admin.config.reports.sub_pages.settings.title"
          />
          <DNavItem
            @route="adminReports.index"
            @label="admin.config.reports.title"
          />
        </:tabs>
      </DPageHeader>
    {{/if}}
  {{/if}}

  <div class="admin-container admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
