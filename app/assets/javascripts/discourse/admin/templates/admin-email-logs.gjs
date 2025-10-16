import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminEmailLogs.sent"
          @label="admin.config.email_logs.sub_pages.sent.title"
        />
        <NavItem
          @route="adminEmailLogs.skipped"
          @label="admin.config.email_logs.sub_pages.skipped.title"
        />
        <NavItem
          @route="adminEmailLogs.bounced"
          @label="admin.config.email_logs.sub_pages.bounced.title"
        />
        <NavItem
          @route="adminEmailLogs.received"
          @label="admin.config.email_logs.sub_pages.received.title"
        />
        <NavItem
          @route="adminEmailLogs.rejected"
          @label="admin.config.email_logs.sub_pages.rejected.title"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container">
      {{outlet}}
    </div>
  </template>
);
