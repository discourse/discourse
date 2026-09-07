import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import DashboardReportEmptyState from "discourse/admin/components/dashboard/report-empty-state";
import DashboardReportErrorState from "discourse/admin/components/dashboard/report-error-state";
import DashboardSection from "discourse/admin/components/dashboard/section";
import ManageReports from "discourse/admin/components/modal/manage-reports";
import { lookupAdminDashboardReportRenderer } from "discourse/admin/lib/admin-dashboard-report-renderers";
import { loadDashboardReports } from "discourse/admin/lib/dashboard-reports-loader";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { prefersReducedMotion } from "discourse/lib/utilities";
import { eq, gt } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;
const MAX_ROWS = 4;
const MAX_COLS = 2;

function computeColumns(cardsLike) {
  const columns = new Map();
  let cursor = 0;
  for (const card of cardsLike) {
    if (card.cols > 1) {
      columns.set(card.key, null);
      cursor = 0;
    } else {
      columns.set(card.key, cursor);
      cursor = cursor === 0 ? 1 : 0;
    }
  }
  return columns;
}

function clampBetween(value, a, b) {
  const lo = Math.min(a, b);
  const hi = Math.max(a, b);
  return Math.min(Math.max(value, lo), hi);
}

class AnimateReflow extends Modifier {
  previousRect = null;
  previousSignature = null;

  modify(element, [signature], { disabled }) {
    if (disabled) {
      this.previousRect = null;
      return;
    }

    if (prefersReducedMotion() || isTesting()) {
      return;
    }

    const firstRun = !this.previousRect;
    if (!firstRun && signature === this.previousSignature) {
      return;
    }
    this.previousSignature = signature;

    if (!firstRun) {
      element.style.transition = "none";
      element.style.transform = "";
    }

    const rect = element.getBoundingClientRect();
    const previous = this.previousRect;
    this.previousRect = rect;

    if (!previous) {
      return;
    }

    const dx = previous.left - rect.left;
    const dy = previous.top - rect.top;
    const scaleX = previous.width / rect.width;
    const scaleY = previous.height / rect.height;
    if (!dx && !dy && scaleX === 1 && scaleY === 1) {
      element.style.transition = "";
      return;
    }

    element.style.transformOrigin = "top left";
    element.style.transform = `translate(${dx}px, ${dy}px) scale(${scaleX}, ${scaleY})`;

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        element.style.transition = "transform 0.2s ease-out";
        element.style.transform = "";
      });
    });
  }
}

class FollowPointer extends Modifier {
  modify(element, [rect]) {
    if (!rect) {
      element.style.left = "";
      element.style.top = "";
      element.style.width = "";
      element.style.height = "";
      return;
    }

    element.style.left = `${rect.left}px`;
    element.style.top = `${rect.top}px`;
    element.style.width = `${rect.width}px`;
    element.style.height = `${rect.height}px`;
  }
}

export default class DashboardReports extends Component {
  @service currentUser;
  @service modal;

  @tracked cards = [];
  @tracked loading = false;
  @tracked liveResize = null;
  @tracked freeFollow = null;
  @tracked activeResizeKey = null;

  measureCard = (handle) => handle.closest(".db-report__card");

  canResize = (card) => this.canEdit && !card.isLoading;

  columnFor = (key) => this.cardColumns.get(key);

  followRectFor = (key) =>
    this.freeFollow?.key === key ? this.freeFollow.rect : null;

  handleDirectionsFor = (card) => {
    if (card.cols > 1 || this.activeResizeKey === card.key) {
      return ["sw", "se"];
    }
    const column = this.cardColumns.get(card.key);
    const innerCornerIsLeft = isDocumentRTL() ? column === 0 : column === 1;
    return [innerCornerIsLeft ? "sw" : "se"];
  };

  constructor() {
    super(...arguments);
    this.loadPayloads();
  }

  get items() {
    return this.args.data?.items ?? [];
  }

  get layoutItems() {
    return this.cards.map(({ source, identifier, rows, cols }) => ({
      source,
      identifier,
      rows: rows || 1,
      cols: cols || 1,
    }));
  }

  get canEdit() {
    return this.currentUser?.admin;
  }

  get addTileVisible() {
    return this.canEdit && this.items.length < VISIBLE_CAP;
  }

  get effectiveCards() {
    if (!this.liveResize) {
      return this.cards;
    }
    return this.cards.map((card) =>
      card.key === this.liveResize.key
        ? { ...card, rows: this.liveResize.rows, cols: this.liveResize.cols }
        : card
    );
  }

  get cardColumns() {
    return computeColumns(this.effectiveCards);
  }

  get resizeSignature() {
    return this.liveResize
      ? `${this.liveResize.key}:${this.liveResize.rows}:${this.liveResize.cols}`
      : null;
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

    this.cards = this.items.map((item) => ({
      ...item,
      payload: null,
      error: false,
      isLoading: true,
    }));

    this.loading = true;
    try {
      const results = await loadDashboardReports({
        items: this.layoutItems,
        filters: this.filters,
      });
      this.cards = this.items.map((item) => {
        const result = results.get(item.key);
        return {
          ...item,
          payload: result?.payload ?? null,
          error: result?.error ?? false,
          isLoading: false,
        };
      });
    } catch (e) {
      this.cards = this.items.map((item) => ({
        ...item,
        payload: null,
        error: true,
        isLoading: false,
      }));
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

  freeFollowRect(
    originRect,
    delta,
    { rowHeight, rowGap, singleWidth, fullWidth, anchorLeft }
  ) {
    const maxHeight = MAX_ROWS * rowHeight + (MAX_ROWS - 1) * rowGap;
    const height = clampBetween(
      originRect.height + delta.y,
      rowHeight,
      maxHeight
    );
    const width = clampBetween(
      originRect.width + (anchorLeft ? delta.x : -delta.x),
      singleWidth,
      fullWidth
    );
    const rightEdge = originRect.left + originRect.width;
    return {
      left: anchorLeft ? originRect.left : rightEdge - width,
      top: originRect.top,
      width,
      height,
    };
  }

  @action
  onCardResizeStart(item, direction, dragInfo) {
    const rect = dragInfo.measuredRect;
    const grid = dragInfo.measured?.closest(".db-section__wrapper");
    if (!rect || !grid) {
      return;
    }

    this.activeResizeKey = item.key;

    const style = getComputedStyle(grid);
    const columnGap = parseFloat(style.columnGap) || 0;
    const rowGap = parseFloat(style.rowGap) || 0;
    const originalRows = item.rows;
    const originalCols = item.cols;

    dragInfo.session.originalRows = originalRows;
    dragInfo.session.originalCols = originalCols;
    dragInfo.session.originRect = rect;
    dragInfo.session.rowHeight =
      originalRows > 1
        ? (rect.height - (originalRows - 1) * rowGap) / originalRows
        : rect.height;
    dragInfo.session.rowGap = rowGap;
    dragInfo.session.singleWidth =
      originalCols > 1 ? (rect.width - columnGap) / 2 : rect.width;
    dragInfo.session.fullWidth =
      originalCols > 1 ? rect.width : rect.width * 2 + columnGap;
    dragInfo.session.anchorLeft = direction === "se";
  }

  @action
  onCardResize(item, _payload, dragInfo) {
    const {
      originalRows,
      originalCols,
      originRect,
      rowHeight,
      rowGap,
      singleWidth,
      fullWidth,
      anchorLeft,
    } = dragInfo.session;
    if (!originRect) {
      return;
    }

    const rawRows = originalRows + dragInfo.delta.y / (rowHeight + rowGap);
    const liveRows = clampBetween(Math.round(rawRows), 1, MAX_ROWS);

    const colUnit = fullWidth - singleWidth;
    const signedDeltaX = anchorLeft ? dragInfo.delta.x : -dragInfo.delta.x;
    const rawCols = originalCols + signedDeltaX / colUnit;
    const liveCols =
      liveRows > 1 ? MAX_COLS : clampBetween(Math.round(rawCols), 1, MAX_COLS);

    this.liveResize = { key: item.key, rows: liveRows, cols: liveCols };
    this.freeFollow = {
      key: item.key,
      rect: this.freeFollowRect(originRect, dragInfo.delta, {
        rowHeight,
        rowGap,
        singleWidth,
        fullWidth,
        anchorLeft,
      }),
    };
  }

  @action
  async onCardResizeEnd(item, _payload, dragInfo) {
    const live = this.liveResize?.key === item.key ? this.liveResize : null;
    this.freeFollow = null;
    this.activeResizeKey = null;

    if (!dragInfo.moved) {
      this.liveResize = null;
      const isNormal = item.rows === 1 && item.cols === 1;
      await this.setSize(
        item,
        isNormal ? { rows: 1, cols: MAX_COLS } : { rows: 1, cols: 1 }
      );
      return;
    }

    if (
      live &&
      (live.rows !== dragInfo.session.originalRows ||
        live.cols !== dragInfo.session.originalCols)
    ) {
      await this.setSize(item, { rows: live.rows, cols: live.cols });
    }

    this.liveResize = null;
  }

  @action
  onCardResizeCancel() {
    this.liveResize = null;
    this.freeFollow = null;
    this.activeResizeKey = null;
  }

  @action
  async setSize(item, { rows, cols }) {
    const nextItems = this.layoutItems.map((i) =>
      i.source === item.source && i.identifier === item.identifier
        ? { ...i, rows, cols }
        : i
    );

    try {
      await ajax("/admin/dashboard/reports/layout", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ items: nextItems }),
      });
      this.cards = this.cards.map((card) =>
        card.key === item.key ? { ...card, rows, cols } : card
      );
    } catch (e) {
      popupAjaxError(e);
    }
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
        <div
          class="db-reports"
          {{didUpdate this.loadPayloads @data @startDate @endDate}}
        >
          {{#each this.effectiveCards key="key" as |card|}}
            {{#if (eq card.key this.freeFollow.key)}}
              <div
                {{AnimateReflow this.resizeSignature}}
                class={{dConcatClass
                  "db-report__card"
                  "--resize-placeholder"
                  (if (gt card.cols 1) "--wide")
                  (if (gt card.rows 1) (concat "--rows-" card.rows))
                }}
                data-column={{this.columnFor card.key}}
              ></div>
            {{/if}}
            <div
              {{FollowPointer (this.followRectFor card.key)}}
              {{AnimateReflow
                this.resizeSignature
                disabled=(eq card.key this.freeFollow.key)
              }}
              class={{dConcatClass
                "db-report__card"
                (if (gt card.cols 1) "--wide")
                (if (gt card.rows 1) (concat "--rows-" card.rows))
                (if (eq card.key this.freeFollow.key) "--floating")
              }}
              data-identifier={{card.key}}
              data-column={{this.columnFor card.key}}
            >
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
                <DConditionalLoadingSpinner
                  @condition={{card.isLoading}}
                  @size="small"
                >
                  {{#if card.error}}
                    <DashboardReportErrorState />
                  {{else if card.payload.empty}}
                    <DashboardReportEmptyState />
                  {{else if card.payload}}
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
                </DConditionalLoadingSpinner>
              </div>
              {{#if (this.canResize card)}}
                <DResizeHandles
                  @directions={{this.handleDirectionsFor card}}
                  @handleClass="db-report__resize-handle"
                  @draggingClass="--resizing"
                  @threshold={{8}}
                  @measure={{this.measureCard}}
                  @onResizeStart={{fn this.onCardResizeStart card}}
                  @onResize={{fn this.onCardResize card}}
                  @onResizeEnd={{fn this.onCardResizeEnd card}}
                  @onResizeCancel={{fn this.onCardResizeCancel card}}
                />
              {{/if}}
            </div>
          {{/each}}

          {{#if this.addTileVisible}}
            <button
              {{AnimateReflow this.resizeSignature}}
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
