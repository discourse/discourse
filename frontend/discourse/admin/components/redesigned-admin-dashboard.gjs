import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConfigureMenu from "discourse/admin/components/dashboard/configure-menu";
import DashboardDateRange from "discourse/admin/components/dashboard/date-range";
import DashboardEngagement from "discourse/admin/components/dashboard/engagement";
import DashboardHighlights from "discourse/admin/components/dashboard/highlights";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import DashboardSkeleton from "discourse/admin/components/dashboard/skeleton";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import DMenu from "discourse/float-kit/components/d-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { deepEqual } from "discourse/lib/object";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function buildPending(committed) {
  return committed?.map((s) => ({ ...s })) ?? [];
}

export default class RedesignedAdminDashboard extends Component {
  @service currentUser;

  @tracked pendingSections;

  _saving = false;
  _opened = false;

  constructor() {
    super(...arguments);
    this.pendingSections = buildPending(this.committedSections);
  }

  get committedSections() {
    return this.args.configuration?.sections ?? [];
  }

  get showSkeleton() {
    return this.args.loadingSections && !this.args.sections;
  }

  @action
  onMenuOpen() {
    this._opened = true;
    this.pendingSections = buildPending(this.committedSections);
  }

  @action
  toggleVisibility(id) {
    this.pendingSections = this.pendingSections.map((s) =>
      s.id === id ? { ...s, visible: !s.visible } : s
    );
  }

  @action
  reorder(fromIndex, toIndex) {
    const next = [...this.pendingSections];
    const [moved] = next.splice(fromIndex, 1);
    next.splice(toIndex, 0, moved);
    this.pendingSections = next;
  }

  @action
  onMenuClose() {
    if (this._saving || !this._opened) {
      return;
    }
    if (deepEqual(this.pendingSections, this.committedSections)) {
      return;
    }

    this._saving = true;
    this.args
      .updateConfiguration(this.pendingSections)
      .catch((e) => {
        popupAjaxError(e);
        this.pendingSections = buildPending(this.committedSections);
      })
      .finally(() => {
        this._saving = false;
      });
  }

  <template>
    <div class="db-toolbar">
      <h1>Dashboard</h1>

      <div class="db-toolbar__actions">
        <DashboardDateRange
          @period={{@period}}
          @startDate={{@startDate}}
          @endDate={{@endDate}}
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
            @onClose={{this.onMenuClose}}
            @onShow={{this.onMenuOpen}}
          >
            <:content>
              <ConfigureMenu
                @sections={{this.pendingSections}}
                @onReorder={{this.reorder}}
                @onToggleVisibility={{this.toggleVisibility}}
              />
            </:content>
          </DMenu>
        {{/if}}
      </div>
    </div>

    <div class="db-main">
      {{#if this.showSkeleton}}
        <DashboardSkeleton />
      {{else}}
        {{#each @sections key="id" as |section|}}
          <div class="db-main__section" data-section-id={{section.id}}>
            {{#if (eq section.id "highlights")}}
              <DashboardHighlights
                @highlights={{section.data}}
                @period={{@period}}
                @loading={{@loadingSections}}
                @fetchError={{@sectionsFetchError}}
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            {{else if (eq section.id "reports")}}
              <DashboardReports
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            {{else if (eq section.id "traffic")}}
              <DashboardTraffic
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            {{else if (eq section.id "engagement")}}
              <DashboardEngagement
                @startDate={{@startDate}}
                @endDate={{@endDate}}
              />
            {{/if}}
          </div>
        {{/each}}

        {{#unless @sections.length}}
          <div class="db-main__empty" role="status" aria-live="polite">
            {{#if this.currentUser.admin}}
              {{i18n "admin.dashboard.configure.empty_state_admin"}}
            {{else}}
              {{i18n "admin.dashboard.configure.empty_state_moderator"}}
            {{/if}}
          </div>
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
