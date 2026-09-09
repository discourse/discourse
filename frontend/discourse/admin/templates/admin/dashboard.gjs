import { LinkTo } from "@ember/routing";
import DashboardProblems from "discourse/admin/components/dashboard-problems";
import RedesignedAdminDashboard from "discourse/admin/components/redesigned-admin-dashboard";
import VersionChecks from "discourse/admin/components/version-checks";
import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.showRedesign}}
    <RedesignedAdminDashboard
      @loadedSections={{@controller.loadedSections}}
      @loadingSections={{@controller.loadingSections}}
      @onIgnoreProblem={{@controller.ignoreProblem}}
      @onRefreshProblems={{@controller.refreshSiteAdvice}}
      @problems={{@controller.problems}}
      @refreshSections={{@controller.fetchSections}}
      @reorderSections={{@controller.reorderSections}}
      @requestedEndDate={{@controller.endDate}}
      @requestedPeriod={{@controller.safePeriod}}
      @requestedStartDate={{@controller.startDate}}
      @sectionsFetchError={{@controller.sectionsFetchError}}
      @setCustomDateRange={{@controller.setCustomDateRange}}
      @setPeriod={{@controller.setPeriod}}
      @toggleSection={{@controller.toggleSection}}
    />
  {{else}}
    <PluginOutlet @connectorTagName="div" @name="admin-dashboard-top" />

    <DPageHeader
      @descriptionLabel={{i18n "admin.config.dashboard.header_description"}}
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.dashboard.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.dashboard.title"}}
          @path="/admin"
        />
      </:breadcrumbs>
    </DPageHeader>

    <PluginOutlet
      @connectorTagName="div"
      @name="admin-dashboard-after-header"
    />

    {{#if @controller.showVersionChecks}}
      <div class="section-top">
        <div class="version-checks">
          <VersionChecks @versionCheck={{@controller.versionCheck}} />
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
        <li class="navigation-item settings">
          <LinkTo
            class="navigation-link"
            @route="adminReports.dashboardSettings"
          >
            {{i18n "admin.config.reports.sub_pages.settings.title"}}
          </LinkTo>
        </li>

        <li class="navigation-item general">
          <LinkTo class="navigation-link" @route="admin.dashboard.general">
            {{i18n "admin.dashboard.general_tab"}}
          </LinkTo>
        </li>

        {{#if @controller.isModerationTabVisible}}
          <li class="navigation-item moderation">
            <LinkTo class="navigation-link" @route="admin.dashboardModeration">
              {{i18n "admin.dashboard.moderation_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        {{#if @controller.isSecurityTabVisible}}
          <li class="navigation-item security">
            <LinkTo class="navigation-link" @route="admin.dashboardSecurity">
              {{i18n "admin.dashboard.security_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        {{#if @controller.isReportsTabVisible}}
          <li class="navigation-item reports">
            <LinkTo class="navigation-link" @route="adminReports">
              {{i18n "admin.dashboard.reports_tab"}}
            </LinkTo>
          </li>
        {{/if}}

        <PluginOutlet @name="admin-dashboard-tabs-after" />
      </ul>
    </nav>

    {{outlet}}

    <span>
      <PluginOutlet @connectorTagName="div" @name="admin-dashboard-bottom" />
    </span>
  {{/if}}
</template>
