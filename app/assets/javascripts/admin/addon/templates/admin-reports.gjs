import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminReports.dashboardSettings"
          @label="admin.config.reports.sub_pages.settings.title"
        />
        <NavItem
          @route="adminReports.index"
          @label="admin.config.reports.title"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
);
