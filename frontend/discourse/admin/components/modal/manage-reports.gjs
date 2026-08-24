import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DModal from "discourse/ui-kit/d-modal";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;
const SEARCH_DEBOUNCE_MS = 200;

/**
 * One report's text and enable toggle, shared between the reorderable rows and
 * the disabled rows below them — the two populations share a look while only
 * one of them carries reorder controls.
 */
const ReportRowContent = <template>
  <div class="manage-reports__row-text">
    <div class="manage-reports__row-heading">
      <span class="manage-reports__title">{{@row.title}}</span>
      {{#if @row.label}}
        <span class="db-report__label">
          {{@row.label}}
        </span>
      {{/if}}
    </div>
    {{#if @row.description}}
      <p class="manage-reports__description">{{@row.description}}</p>
    {{/if}}
  </div>

  <DToggleSwitch
    @state={{@enabled}}
    disabled={{@toggleDisabled}}
    aria-label={{i18n
      (if
        @enabled
        "admin.dashboard.reports_section.modal.disable"
        "admin.dashboard.reports_section.modal.enable"
      )
      title=@row.title
    }}
    {{on "click" (fn @onToggle @row)}}
  />
</template>;

export default class ManageReports extends Component {
  @tracked allKeys = [];
  @tracked enabledOrder = [];
  @tracked providers = [];
  @tracked search = "";
  @tracked nextCursor = null;
  @tracked hasMore = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked applying = false;
  itemsByKey = new Map();

  isEnabled = (row) => this.enabledKeys.has(row.key);
  toggleDisabled = (row) => this.atCap && !this.isEnabled(row);
  rowTitle = (row) => row.title;

  constructor() {
    super(...arguments);
    this.load();
  }

  get enabledKeys() {
    return new Set(this.enabledOrder);
  }

  get enabledRows() {
    return this.enabledOrder
      .map((key) => this.itemsByKey.get(key))
      .filter(Boolean);
  }

  get allRows() {
    return this.allKeys.map((key) => this.itemsByKey.get(key)).filter(Boolean);
  }

  get disabledRows() {
    return this.allRows.filter((row) => !this.enabledKeys.has(row.key));
  }

  get filteredEnabledRows() {
    const query = this.search.trim().toLowerCase();
    if (!query) {
      return this.enabledRows;
    }
    return this.enabledRows.filter(
      (row) =>
        (row.title ?? "").toLowerCase().includes(query) ||
        (row.description ?? "").toLowerCase().includes(query)
    );
  }

  get atCap() {
    return this.enabledOrder.length >= VISIBLE_CAP;
  }

  get reorderable() {
    return this.enabledOrder.length > 1;
  }

  get visibleRowCount() {
    return this.filteredEnabledRows.length + this.disabledRows.length;
  }

  cacheItems(items) {
    for (const item of items) {
      this.itemsByKey.set(item.key, item);
    }
  }

  @action
  async load() {
    this.loading = true;
    try {
      const response = await this.fetchAll(null);
      const enabled = response.enabled ?? [];
      const page = response.available ?? [];

      this.providers = response.providers ?? [];
      this.cacheItems(enabled);
      this.cacheItems(page);
      this.enabledOrder = enabled.map((item) => item.key);
      this.allKeys = page.map((item) => item.key);
      this.nextCursor = response.cursor ?? null;
      this.hasMore = !!response.has_more;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore || !this.nextCursor) {
      return;
    }
    this.loadingMore = true;
    try {
      const response = await this.fetchAll(this.nextCursor);
      const page = response.available ?? [];
      this.cacheItems(page);
      this.allKeys = [...this.allKeys, ...page.map((item) => item.key)];
      this.nextCursor = response.cursor ?? null;
      this.hasMore = !!response.has_more;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  async fetchAll(cursor) {
    const data = {};
    if (cursor) {
      data.cursor = cursor;
    }
    if (this.search.trim()) {
      data.search = this.search.trim();
    }
    return await ajax("/admin/dashboard/reports/available.json", { data });
  }

  @action
  updateSearch(event) {
    this.search = event.target.value;
    discourseDebounce(this, this.refetchForSearch, SEARCH_DEBOUNCE_MS);
  }

  @action
  async refetchForSearch() {
    try {
      const response = await this.fetchAll(null);
      const enabled = response.enabled ?? [];
      const page = response.available ?? [];
      this.cacheItems(enabled);
      this.cacheItems(page);
      this.allKeys = page.map((item) => item.key);
      this.nextCursor = response.cursor ?? null;
      this.hasMore = !!response.has_more;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  toggle(row) {
    this.itemsByKey.set(row.key, row);
    if (this.enabledKeys.has(row.key)) {
      this.enabledOrder = this.enabledOrder.filter((k) => k !== row.key);
    } else if (!this.atCap) {
      this.enabledOrder = [...this.enabledOrder, row.key];
    }
  }

  /**
   * Projects a committed move back onto the stored order. The list works in
   * the displayed rows only, so a row a search filter is hiding keeps the
   * slot it already held — letting a move carry rows across hidden ones would
   * persist a change nothing on screen accounts for.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.enabledOrder = this.#storedOrderFrom(
      move.proposedToItems.map((row) => row.key)
    );
  }

  @action
  async apply() {
    this.applying = true;
    try {
      await ajax("/admin/dashboard/reports/layout", {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          items: this.enabledRows.map(({ source, identifier }) => ({
            source,
            identifier,
          })),
        }),
      });
      this.args.closeModal?.();
      this.args.model?.onApplied?.();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.applying = false;
    }
  }

  /**
   * Rebuilds the stored order from a reordered displayed list.
   *
   * A reorder permutes the rows the user can see among the slots they occupy,
   * so a row a search filter is hiding keeps the slot it already held.
   *
   * @param {string[]} nextVisible - The displayed keys in their new order.
   * @returns {string[]} The full stored order.
   */
  #storedOrderFrom(nextVisible) {
    const remaining = [...nextVisible];
    const visible = new Set(nextVisible);
    return this.enabledOrder.map((key) =>
      visible.has(key) ? remaining.shift() : key
    );
  }

  <template>
    <DModal
      @title={{i18n "admin.dashboard.reports_section.modal.title"}}
      @closeModal={{@closeModal}}
      class="manage-reports has-search"
    >

      <:belowModalTitle>
        <span class="manage-reports__counter">
          {{i18n
            "admin.dashboard.reports_section.modal.counter"
            count=this.enabledOrder.length
            max=VISIBLE_CAP
          }}
        </span>
      </:belowModalTitle>

      <:belowHeader>
        <div class="manage-reports__search-wrapper">
          <DFilterInput
            @icons={{hash left="magnifying-glass"}}
            @value={{this.search}}
            @filterAction={{this.updateSearch}}
            placeholder={{i18n
              "admin.dashboard.reports_section.modal.search_placeholder"
            }}
          />
        </div>
      </:belowHeader>

      <:body>

        {{#if this.visibleRowCount}}
          <DReorderableList
            @items={{this.filteredEnabledRows}}
            @key="key"
            @label={{this.rowTitle}}
            @onMove={{this.handleMove}}
            @rowClass="manage-reports__row --enabled"
            class={{dConcatClass
              "manage-reports__list"
              (if this.reorderable "--reorderable")
            }}
          >
            <:row as |row|>
              <ReportRowContent
                @row={{row}}
                @enabled={{true}}
                @toggleDisabled={{this.toggleDisabled row}}
                @onToggle={{this.toggle}}
              />
            </:row>
            <:static>
              {{#each this.disabledRows key="key" as |row|}}
                <li
                  class="manage-reports__row"
                  data-reorderable-key={{row.key}}
                >
                  <ReportRowContent
                    @row={{row}}
                    @enabled={{false}}
                    @toggleDisabled={{this.toggleDisabled row}}
                    @onToggle={{this.toggle}}
                  />
                </li>
              {{/each}}
            </:static>
          </DReorderableList>
          <DLoadMore
            @action={{this.loadMore}}
            @enabled={{this.hasMore}}
            @isLoading={{this.loading}}
          />
        {{/if}}

      </:body>

      <:aboveFooter>
        <PluginOutlet
          @name="admin-dashboard-manage-reports-footer"
          @outletArgs={{lazyHash
            providers=this.providers
            enabled=this.enabledRows
          }}
        />
      </:aboveFooter>

      <:footer>
        <p class="manage-reports__footer-note">
          {{i18n "admin.dashboard.reports_section.modal.footer_note"}}
        </p>
        <div class="manage-reports__footer-actions">

          <DButton
            @label="js.cancel_value"
            @action={{@closeModal}}
            class="btn-transparent manage-reports__cancel"
          />
          <DButton
            @label="admin.dashboard.reports_section.modal.apply"
            @action={{this.apply}}
            @disabled={{this.applying}}
            @isLoading={{this.applying}}
            class="btn-primary manage-reports__apply"
          />
        </div>

      </:footer>
    </DModal>
  </template>
}
