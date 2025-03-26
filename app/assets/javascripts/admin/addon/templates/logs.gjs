import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminLogs.staffActionLogs"
          @label="admin.config.staff_action_logs.title"
        />
        {{#if @controller.currentUser.can_see_emails}}
          <NavItem
            @route="adminLogs.screenedEmails"
            @label="admin.config.staff_action_logs.sub_pages.screened_emails.title"
          />
        {{/if}}
        <NavItem
          @route="adminLogs.screenedIpAddresses"
          @label="admin.config.staff_action_logs.sub_pages.screened_ips.title"
        />
        <NavItem
          @route="adminLogs.screenedUrls"
          @label="admin.config.staff_action_logs.sub_pages.screened_urls.title"
        />
        <NavItem
          @route="adminSearchLogs"
          @label="admin.config.staff_action_logs.sub_pages.search_logs.title"
        />
        {{#if @controller.currentUser.admin}}
          <NavItem @path="/logs" @label="admin.logs.logster.title" />
        {{/if}}
      </:tabs>
    </DPageHeader>

    <div class="admin-container">
      {{outlet}}
    </div>
  </template>
);
