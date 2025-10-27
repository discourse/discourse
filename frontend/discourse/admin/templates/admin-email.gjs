import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.email.title"}}
      @descriptionLabel={{i18n "admin.config.email.header_description"}}
      @shouldDisplay={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/email"
          @label={{i18n "admin.config.email.title"}}
        />
      </:breadcrumbs>
      <:tabs>
        <NavItem @route="adminEmail.settings" @label="settings" />
        <NavItem
          @route="adminEmail.serverSettings"
          @label="admin.config.email.sub_pages.server_settings.title"
        />
        <NavItem
          @route="adminEmail.previewDigest"
          @label="admin.config.email.sub_pages.preview_summary.title"
        />
        <NavItem
          @route="adminEmail.advancedTest"
          @label="admin.config.email.sub_pages.advanced_test.title"
        />
        <NavItem
          @route="adminEmailTemplates"
          @label="admin.config.email.sub_pages.templates.title"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container">
      {{outlet}}
    </div>
  </template>
);
