import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
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
      <DNavItem @route="adminEmail.settings" @label="settings" />
      <DNavItem
        @route="adminEmail.serverSettings"
        @label="admin.config.email.sub_pages.server_settings.title"
      />
      <DNavItem
        @route="adminEmail.previewDigest"
        @label="admin.config.email.sub_pages.preview_summary.title"
      />
      <DNavItem
        @route="adminEmail.advancedTest"
        @label="admin.config.email.sub_pages.advanced_test.title"
      />
      <DNavItem
        @route="adminEmailTemplates"
        @label="admin.config.email.sub_pages.templates.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
