import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminReports from "admin/components/admin-reports";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.reports.title"}}
      @descriptionLabel={{i18n "admin.config.reports.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/-/240233"
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin.config.reports"
          @label={{i18n "admin.config.reports.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <div class="admin-config-area__full-width">
        <AdminReports />
      </div>
    </div>
  </template>
);
