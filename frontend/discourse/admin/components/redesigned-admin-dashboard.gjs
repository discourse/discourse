import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
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

export default class RedesignedAdminDashboard extends Component {
  @service currentUser;

  @tracked pendingSections;

  _saving = false;
  _opened = false;

  constructor() {
    super(...arguments);
    this.pendingSections = this.#buildPendingSections(
      this.args.loadedSections?.configuration?.sections
    );
  }

  @action
  onMenuOpen() {
    this._opened = true;
    this.pendingSections = this.#buildPendingSections(
      this.args.loadedSections?.configuration?.sections
    );
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

    const committedSections =
      this.args.loadedSections?.configuration?.sections ?? [];

    if (deepEqual(this.pendingSections, committedSections)) {
      return;
    }

    this._saving = true;
    this.args
      .updateConfiguration(this.pendingSections)
      .catch((e) => {
        popupAjaxError(e);
        this.pendingSections = this.#buildPendingSections(
          this.args.loadedSections?.configuration?.sections
        );
      })
      .finally(() => {
        this._saving = false;
      });
  }

  #buildPendingSections(sections) {
    return sections?.map((section) => ({ ...section })) ?? [];
  }

  <template>
    <div class="db-header">
      <h1 class="db-header__title">Dashboard</h1>
      <div class="db-header__actions">
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
      {{#if @loadedSections}}
        {{#each @loadedSections.sections key="id" as |section|}}
          {{#if (eq section.id "highlights")}}
            <DashboardHighlights
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @highlights={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{@sectionsFetchError}}
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
            />
          {{else if (eq section.id "traffic")}}
            <DashboardTraffic
              class={{concat "--" section.id}}
              data-section-id={{section.id}}
              @traffic={{section.data}}
              @period={{@loadedSections.period}}
              @loading={{@loadingSections}}
              @fetchError={{@sectionsFetchError}}
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
              @fetchError={{@sectionsFetchError}}
              @startDate={{@loadedSections.startDate}}
              @endDate={{@loadedSections.endDate}}
            />
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
