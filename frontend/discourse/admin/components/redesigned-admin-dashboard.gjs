import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import ConfigureMenu from "discourse/admin/components/dashboard/configure-menu";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import DashboardHighlights from "discourse/admin/components/dashboard/highlights";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import DashboardSearch from "discourse/admin/components/dashboard/search";
import DashboardSiteAdvice from "discourse/admin/components/dashboard/site-advice";
import DashboardSkeleton from "discourse/admin/components/dashboard/skeleton";
import DashboardSystem from "discourse/admin/components/dashboard/system";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import { lookupAdminDashboardSection } from "discourse/admin/lib/admin-dashboard-sections";
import PluginOutlet from "discourse/components/plugin-outlet";
import DMenu from "discourse/float-kit/components/d-menu";
import lazyHash from "discourse/helpers/lazy-hash";
import { eq } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

const sectionComponentFor = (id) => lookupAdminDashboardSection(id);

export default class RedesignedAdminDashboard extends Component {
  @service currentUser;

  get configurationSections() {
    return this.args.loadedSections?.configuration?.sections ?? [];
  }

  <template>
    <DPageHeader
      @collapseActionsOnMobile={{false}}
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

      <:actions>
        <DashboardDateRange
          @endDate={{@requestedEndDate}}
          @period={{@requestedPeriod}}
          @setCustomDateRange={{@setCustomDateRange}}
          @setPeriod={{@setPeriod}}
          @startDate={{@requestedStartDate}}
        />
        {{#if this.currentUser.admin}}
          <DMenu
            @icon="gear"
            @identifier="db-configure"
            @label={{i18n "admin.dashboard.configure.button"}}
            @modalForMobile={{true}}
            @title={{i18n "admin.dashboard.configure.tooltip"}}
            @triggerClass="btn-default"
          >
            <:content>
              <ConfigureMenu
                @onReorder={{@reorderSections}}
                @onToggleVisibility={{@toggleSection}}
                @sections={{this.configurationSections}}
              />
            </:content>
          </DMenu>
        {{/if}}
      </:actions>
    </DPageHeader>

    <PluginOutlet
      @connectorTagName="div"
      @name="admin-dashboard-after-header"
      @outletArgs={{lazyHash isNewDashboard=true}}
    />

    <div class="db-main">
      {{#if @sectionsFetchError}}
        <div class="db-main__error" role="alert">
          {{i18n "admin.dashboard.fetch_error"}}
        </div>
      {{else if @loadedSections}}
        <DashboardSiteAdvice
          @onIgnore={{@onIgnoreProblem}}
          @onRefresh={{@onRefreshProblems}}
          @problems={{@problems}}
        />

        {{#each @loadedSections.sections key="id" as |section|}}
          {{#if (eq section.id "highlights")}}
            <DashboardHighlights
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @endDate={{@loadedSections.endDate}}
              @fetchError={{section.error}}
              @highlights={{section.data}}
              @loading={{@loadingSections}}
              @period={{@loadedSections.period}}
              @startDate={{@loadedSections.startDate}}
            />
          {{else if (eq section.id "reports")}}
            <DashboardReports
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @data={{section.data}}
              @endDate={{@loadedSections.endDate}}
              @fetchError={{section.error}}
              @refreshSections={{@refreshSections}}
              @startDate={{@loadedSections.startDate}}
            />
          {{else if (eq section.id "traffic")}}
            <DashboardTraffic
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @endDate={{@loadedSections.endDate}}
              @fetchError={{section.error}}
              @loading={{@loadingSections}}
              @period={{@loadedSections.period}}
              @startDate={{@loadedSections.startDate}}
              @traffic={{section.data}}
            />
          {{else if (eq section.id "engagement")}}
            <DashboardEngagement
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @endDate={{@loadedSections.endDate}}
              @engagement={{section.data}}
              @fetchError={{section.error}}
              @loading={{@loadingSections}}
              @startDate={{@loadedSections.startDate}}
            />
          {{else if (eq section.id "system")}}
            <DashboardSystem
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @data={{section.data}}
              @fetchError={{section.error}}
              @loading={{@loadingSections}}
            />
          {{else if (eq section.id "search")}}
            <DashboardSearch
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @endDate={{@loadedSections.endDate}}
              @fetchError={{section.error}}
              @loading={{@loadingSections}}
              @period={{@loadedSections.period}}
              @search={{section.data}}
              @startDate={{@loadedSections.startDate}}
            />
          {{else}}
            {{#let (sectionComponentFor section.id) as |PluginSection|}}
              {{#if PluginSection}}
                <PluginSection
                  class={{concat "--" section.id}}
                  data-section-id={{section.id}}
                  @data={{section.data}}
                  @endDate={{@loadedSections.endDate}}
                  @fetchError={{section.error}}
                  @loading={{@loadingSections}}
                  @period={{@loadedSections.period}}
                  @startDate={{@loadedSections.startDate}}
                />
              {{/if}}
            {{/let}}
          {{/if}}
        {{/each}}

        {{#unless @loadedSections.sections.length}}
          <div aria-live="polite" class="db-main__empty" role="status">
            {{#if this.currentUser.admin}}
              {{i18n "admin.dashboard.configure.empty_state_admin"}}
            {{else}}
              {{i18n "admin.dashboard.configure.empty_state_moderator"}}
            {{/if}}
          </div>
        {{/unless}}
      {{else if @loadingSections}}
        <DashboardSkeleton />
      {{/if}}
    </div>
  </template>
}
