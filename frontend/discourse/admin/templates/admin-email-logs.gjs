import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.email_logs.header_description"}}
    @shouldDisplay={{true}}
    @titleLabel={{i18n "admin.config.email_logs.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.email_logs.title"}}
        @path="/admin/email-logs"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @label="admin.config.email_logs.sub_pages.sent.title"
        @route="adminEmailLogs.sent"
      />
      <DNavItem
        @label="admin.config.email_logs.sub_pages.skipped.title"
        @route="adminEmailLogs.skipped"
      />
      <DNavItem
        @label="admin.config.email_logs.sub_pages.bounced.title"
        @route="adminEmailLogs.bounced"
      />
      <DNavItem
        @label="admin.config.email_logs.sub_pages.received.title"
        @route="adminEmailLogs.received"
      />
      <DNavItem
        @label="admin.config.email_logs.sub_pages.rejected.title"
        @route="adminEmailLogs.rejected"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
