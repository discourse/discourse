import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.email_logs.title"}}
    @descriptionLabel={{i18n "admin.config.email_logs.header_description"}}
    @shouldDisplay={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/email-logs"
        @label={{i18n "admin.config.email_logs.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminEmailLogs.sent"
        @label="admin.config.email_logs.sub_pages.sent.title"
      />
      <DNavItem
        @route="adminEmailLogs.skipped"
        @label="admin.config.email_logs.sub_pages.skipped.title"
      />
      <DNavItem
        @route="adminEmailLogs.bounced"
        @label="admin.config.email_logs.sub_pages.bounced.title"
      />
      <DNavItem
        @route="adminEmailLogs.received"
        @label="admin.config.email_logs.sub_pages.received.title"
      />
      <DNavItem
        @route="adminEmailLogs.rejected"
        @label="admin.config.email_logs.sub_pages.rejected.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
