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
      @titleLabel={{i18n "admin.dashboard.title"}}
      @hideTabs={{true}}
      @collapseActionsOnMobile={{false}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin"
          @label={{i18n "admin.dashboard.title"}}
        />
      </:breadcrumbs>

      <:actions>
        <DashboardDateRange
          @period={{@requestedPeriod}}
          @startDate={{@requestedStartDate}}
          @endDate={{@requestedEndDate}}
          @setPeriod={{@setPeriod}}
          @setCustomDateRange={{@setCustomDateRange}}
        />
        {{#if this.currentUser.admin}}
          <DMenu
            @identifier="db-configure"
            @icon="gear"
            @label={{i18n "admin.dashboard.configure.button"}}
            @title={{i18n "admin.dashboard.configure.tooltip"}}
            @triggerClass="btn-default"
            @modalForMobile={{true}}
          >
            <:content>
              <ConfigureMenu
                @sections={{this.configurationSections}}
                @onReorder={{@reorderSections}}
                @onToggleVisibility={{@toggleSection}}
              />
            </:content>
          </DMenu>
        {{/if}}
      </:actions>
    </DPageHeader>

    <PluginOutlet
      @name="admin-dashboard-after-header"
      @connectorTagName="div"
      @outletArgs={{lazyHash isNewDashboard=true}}
    />

    <div class="db-main">
      {{#if @sectionsFetchError}}
        <div class="db-main__error" role="alert">
          {{i18n "admin.dashboard.fetch_error"}}
        </div>
      {{else if @loadedSections}}
        <DashboardSiteAdvice
          @problems={{@problems}}
          @onRefresh={{@onRefreshProblems}}
          @onIgnore={{@onIgnoreProblem}}
        />

        {{#each @loadedSections.sections key="id" as |section|}}
          {{#if (eq section.id "highlights")}}
            <DashboardHighlights
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @highlights={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{section.error}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
            />
          {{else if (eq section.id "reports")}}
            <DashboardReports
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @data={{section.data}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
              @refreshSections={{@refreshSections}}
              @fetchError={{section.error}}
            />
          {{else if (eq section.id "traffic")}}
            <DashboardTraffic
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @traffic={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{section.error}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
            />
          {{else if (eq section.id "engagement")}}
            <DashboardEngagement
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @engagement={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{section.error}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
            />
          {{else if (eq section.id "search")}}
            <DashboardSearch
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @search={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{section.error}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
            />
          {{else}}
            {{#let (sectionComponentFor section.id) as |PluginSection|}}
              {{#if PluginSection}}
                <PluginSection
                  class={{concat "--" section.id}}
                  data-section-id={{section.id}}
                  @data={{section.data}}
                  @period={{@loadedSections.period}}
                  @loading={{@loadingSections}}
                  @fetchError={{section.error}}
                  @startDate={{@loadedSections.startDate}}
                  @endDate={{@loadedSections.endDate}}
                />
              {{/if}}
            {{/let}}
          {{/if}}
        {{/each}}

        {{#unless @loadedSections.sections.length}}
          <div class="db-main__empty" role="status" aria-live="polite">
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
