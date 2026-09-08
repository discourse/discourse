import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n
      "admin.config.staff_action_logs.header_description"
    }}
    @shouldDisplay={{true}}
    @titleLabel={{i18n "admin.config.staff_action_logs.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.staff_action_logs.title"}}
        @path="/admin/logs"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @label="admin.config.staff_action_logs.title"
        @route="adminLogs.staffActionLogs"
      />
      {{#if @controller.currentUser.can_see_emails}}
        <DNavItem
          @label="admin.config.staff_action_logs.sub_pages.screened_emails.title"
          @route="adminLogs.screenedEmails"
        />
      {{/if}}
      {{#if @controller.currentUser.can_see_ip}}
        <DNavItem
          @label="admin.config.staff_action_logs.sub_pages.screened_ips.title"
          @route="adminLogs.screenedIpAddresses"
        />
      {{/if}}
      <DNavItem
        @label="admin.config.staff_action_logs.sub_pages.screened_urls.title"
        @route="adminLogs.screenedUrls"
      />
      <DNavItem
        @label="admin.config.staff_action_logs.sub_pages.search_logs.title"
        @route="adminSearchLogs"
      />
      {{#if @controller.currentUser.admin}}
        <DNavItem @label="admin.logs.logster.title" @path="/logs" />
      {{/if}}
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
