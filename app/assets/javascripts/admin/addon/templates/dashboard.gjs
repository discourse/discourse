import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";
import DashboardProblems from "admin/components/dashboard-problems";
import VersionChecks from "admin/components/version-checks";

export default RouteTemplate(
  <template>
    <PluginOutlet @name="admin-dashboard-top" @connectorTagName="div" />

    <DPageHeader
      @titleLabel={{i18n "admin.dashboard.title"}}
      @descriptionLabel={{i18n "admin.config.dashboard.header_description"}}
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin"
          @label={{i18n "admin.dashboard.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <PluginOutlet
      @name="admin-dashboard-after-header"
      @connectorTagName="div"
    />

    {{#if @controller.showVersionChecks}}
      <div class="section-top">
        <div class="version-checks">
          <VersionChecks
            @versionCheck={{@controller.versionCheck}}
            @tagName=""
          />
        </div>
      </div>
    {{/if}}

    <DashboardProblems
      @loadingProblems={{@controller.loadingProblems}}
      @problems={{@controller.problems}}
      @problemsTimestamp={{@controller.problemsTimestamp}}
      @refreshProblems={{@controller.refreshProblems}}
    />
    <nav>
      <ul class="nav nav-pills">
        <li class="navigation-item general">
          <LinkTo @route="admin.dashboard.general" class="navigation-link">
            {{i18n "admin.dashboard.general_tab"}}
          </LinkTo>
        </li>

        {{#if @controller.isModerationTabVisible}}
          <li class="navigation-item moderation">
            <LinkTo @route="admin.dashboardModeration" class="navigation-link">
              {{i18n "admin.dashboard.moderation_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        {{#if @controller.isSecurityTabVisible}}
          <li class="navigation-item security">
            <LinkTo @route="admin.dashboardSecurity" class="navigation-link">
              {{i18n "admin.dashboard.security_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        {{#if @controller.isReportsTabVisible}}
          <li class="navigation-item reports">
            <LinkTo @route="admin.dashboardReports" class="navigation-link">
              {{i18n "admin.dashboard.reports_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        <PluginOutlet @name="admin-dashboard-tabs-after" />
      </ul>
    </nav>

    {{outlet}}

    <span>
      <PluginOutlet @name="admin-dashboard-bottom" @connectorTagName="div" />
    </span>
  </template>
);
