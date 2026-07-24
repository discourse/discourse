import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DashboardReportEmptyState from "discourse/admin/components/dashboard/report-empty-state";
import DashboardSection from "discourse/admin/components/dashboard/section";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import { lookupAdminDashboardReportRenderer } from "discourse/admin/lib/admin-dashboard-report-renderers";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;

export default class DashboardReports extends Component {
  @service currentUser;
  @service modal;

  get items() {
    return this.args.data?.items ?? [];
  }

  get layoutItems() {
    return this.items.map(({ source, identifier }) => ({
      source,
      identifier,
    }));
  }

  get canEdit() {
    return this.currentUser?.admin;
  }

  get addTileVisible() {
    return this.canEdit && this.items.length < VISIBLE_CAP;
  }

  @action
  openReportsConfig() {
    this.modal.show(ManageReports, {
      model: { onApplied: this.onLayoutChanged },
    });
  }

  @action
  async removeReport(item) {
    const nextItems = this.layoutItems.filter(
      (i) => !(i.source === item.source && i.identifier === item.identifier)
    );

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
      @description={{i18n "admin.dashboard.reports_section.description"}}
      @bordered={{false}}
      @layout="grid"
      @headerActionIcon={{if this.canEdit "gear"}}
      @headerActionLabel="admin.dashboard.reports_section.header_action"
      @headerAction={{if this.canEdit this.openReportsConfig}}
      @startDate={{@startDate}}
      @endDate={{@endDate}}
      ...attributes
    >
      {{#if @fetchError}}
        <div class="db-section__error" role="alert">
          {{i18n "admin.dashboard.sections.reports.fetch_error"}}
        </div>
      {{else}}
        <div class="db-reports">
          {{#each this.items key="key" as |card|}}
            <div class="db-report__card" data-identifier={{card.key}}>
              <div class="db-report__header">
                <a href={{card.url}} class="db-report__name">{{card.title}}</a>
                {{#if card.label}}
                  <div
                    class={{dConcatClass
                      "db-report__label"
                      (concat "--" card.source)
                    }}
                    data-source={{card.source}}
                  >{{card.label}}</div>
                {{/if}}
              </div>
              <div class="db-report__chart">
                {{#if card.payload}}
                  {{#if card.payload.empty}}
                    <DashboardReportEmptyState />
                  {{else}}
                    {{#let
                      (lookupAdminDashboardReportRenderer card.source)
                      as |Renderer|
                    }}
                      {{#if Renderer}}
                        <Renderer
                          @item={{card}}
                          @payload={{card.payload}}
                          @filters={{hash
                            startDate=@startDate
                            endDate=@endDate
                          }}
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
      {{/if}}

      <PluginOutlet
        @name="admin-dashboard-reports-section-after"
        @outletArgs={{lazyHash startDate=@startDate endDate=@endDate}}
      />
    </DashboardSection>
  </template>
}
