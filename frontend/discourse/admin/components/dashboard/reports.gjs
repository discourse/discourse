import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DashboardReportEmptyState from "discourse/admin/components/dashboard/report-empty-state";
import DashboardSection from "discourse/admin/components/dashboard/section";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import { lookupAdminDashboardReportRenderer } from "discourse/admin/lib/admin-dashboard-report-renderers";
import { loadDashboardReports } from "discourse/admin/lib/dashboard-reports-loader";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;

const rendererFor = (source) => lookupAdminDashboardReportRenderer(source);

export default class DashboardReports extends Component {
  @service currentUser;
  @service modal;

  @tracked cards = [];
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.cards = this.items.map((item) => ({ ...item, payload: null }));
    this.loadPayloads();
  }

  get items() {
    return this.args.data?.items ?? [];
  }

  get showLabels() {
    return this.args.data?.show_labels ?? false;
  }

  get canEdit() {
    return this.currentUser?.admin;
  }

  get addTileVisible() {
    return this.canEdit && this.items.length < VISIBLE_CAP;
  }

  @cached
  get filters() {
    const filters = {};
    if (this.args.startDate) {
      filters.start_date = moment(this.args.startDate).format("YYYY-MM-DD");
    }
    if (this.args.endDate) {
      filters.end_date = moment(this.args.endDate).format("YYYY-MM-DD");
    }
    return filters;
  }

  @action
  async loadPayloads() {
    if (!this.items.length) {
      this.cards = [];
      return;
    }

    this.loading = true;
    try {
      const payloads = await loadDashboardReports({
        items: this.items.map(({ source, identifier }) => ({
          source,
          identifier,
        })),
        filters: this.filters,
      });
      this.cards = this.items.map((item) => ({
        ...item,
        payload: payloads.get(item.key),
      }));
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  openReportsConfig() {
    this.modal.show(ManageReports, {
      model: { onApplied: this.onLayoutChanged },
    });
  }

  @action
  async removeReport(item) {
    const nextItems = this.items
      .filter(
        (i) => !(i.source === item.source && i.identifier === item.identifier)
      )
      .map(({ source, identifier }) => ({ source, identifier }));

    try {
      await ajax("/admin/dashboard/reports/layout", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ items: nextItems }),
      });
      await this.onLayoutChanged();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async onLayoutChanged() {
    if (this.args.refreshSections) {
      await this.args.refreshSections();
    }
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.reports.title"}}
      @bordered={{false}}
      @layout="grid"
      @headerActionIcon={{if this.canEdit "gear"}}
      @headerAction={{if this.canEdit this.openReportsConfig}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
    >
      <div
        class="db-reports"
        {{didUpdate this.loadPayloads @data @startDate @endDate}}
      >
        {{#each this.cards key="key" as |card|}}
          <div class="db-report__card" data-identifier={{card.key}}>
            <div class="db-report__header">
              <span class="db-report__name">{{card.title}}</span>
              {{#if this.showLabels}}
                <div
                  class="db-report__label"
                  data-source={{card.source}}
                >{{card.label}}</div>
              {{/if}}
              {{#if this.canEdit}}
                <DButton
                  @icon="xmark"
                  @translatedAriaLabel={{i18n
                    "admin.dashboard.reports_section.remove"
                  }}
                  @action={{fn this.removeReport card}}
                  class="db-report__remove btn-transparent btn-small"
                />
              {{/if}}
            </div>
            <div class="db-report__chart">
              {{#if card.payload}}
                {{#if card.payload.empty}}
                  <DashboardReportEmptyState />
                {{else}}
                  {{#let (rendererFor card.source) as |Renderer|}}
                    {{#if Renderer}}
                      <Renderer
                        @item={{card}}
                        @payload={{card.payload}}
                        @filters={{hash startDate=@startDate endDate=@endDate}}
                      />
                    {{/if}}
                  {{/let}}
                {{/if}}
              {{/if}}
            </div>
          </div>
        {{/each}}

        {{#if this.addTileVisible}}
          <button
            type="button"
            class="db-report__add-report"
            aria-label={{i18n "admin.dashboard.reports_section.add"}}
            {{on "click" this.openReportsConfig}}
          >
            <span>{{dIcon "plus"}}
              {{i18n "admin.dashboard.reports_section.add"}}</span>
          </button>
        {{/if}}
      </div>

      <PluginOutlet
        @name="admin-dashboard-reports-section-after"
        @outletArgs={{lazyHash startDate=@startDate endDate=@endDate}}
      />
    </DashboardSection>
  </template>
}
