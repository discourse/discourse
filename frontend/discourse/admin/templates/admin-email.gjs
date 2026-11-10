import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.email.header_description"}}
    @shouldDisplay={{true}}
    @titleLabel={{i18n "admin.config.email.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.email.title"}}
        @path="/admin/email"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem @label="settings" @route="adminEmail.settings" />
      <DNavItem
        @label="admin.config.email.sub_pages.server_settings.title"
        @route="adminEmail.serverSettings"
      />
      <DNavItem
        @label="admin.config.email.sub_pages.preview_summary.title"
        @route="adminEmail.previewDigest"
      />
      <DNavItem
        @label="admin.config.email.sub_pages.advanced_test.title"
        @route="adminEmail.advancedTest"
      />
      <DNavItem
        @label="admin.config.email.sub_pages.templates.title"
        @route="adminEmailTemplates"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
