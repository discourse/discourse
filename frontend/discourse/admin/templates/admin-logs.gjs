import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.staff_action_logs.title"}}
    @descriptionLabel={{i18n
      "admin.config.staff_action_logs.header_description"
    }}
    @shouldDisplay={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/logs"
        @label={{i18n "admin.config.staff_action_logs.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminLogs.staffActionLogs"
        @label="admin.config.staff_action_logs.title"
      />
      {{#if @controller.currentUser.can_see_emails}}
        <DNavItem
          @route="adminLogs.screenedEmails"
          @label="admin.config.staff_action_logs.sub_pages.screened_emails.title"
        />
      {{/if}}
      {{#if @controller.currentUser.can_see_ip}}
        <DNavItem
          @route="adminLogs.screenedIpAddresses"
          @label="admin.config.staff_action_logs.sub_pages.screened_ips.title"
        />
      {{/if}}
      <DNavItem
        @route="adminLogs.screenedUrls"
        @label="admin.config.staff_action_logs.sub_pages.screened_urls.title"
      />
      <DNavItem
        @route="adminSearchLogs"
        @label="admin.config.staff_action_logs.sub_pages.search_logs.title"
      />
      {{#if @controller.currentUser.admin}}
        <DNavItem @path="/logs" @label="admin.logs.logster.title" />
      {{/if}}
    </:tabs>
  </DPageHeader>

  <div class="admin-container">
    {{outlet}}
  </div>
</template>
