import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ManageableRowListItemReorderable from "discourse/admin/components/manageable-row-list-item-reorderable";
import ToggleableOrderedList from "discourse/admin/lib/toggleable-ordered-list";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DModal from "discourse/ui-kit/d-modal";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;
const SEARCH_DEBOUNCE_MS = 200;
const ARIA_LABEL_PREFIX = "admin.dashboard.reports_section.modal";

/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `modal/manage-reports.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `modal/manage-reports.gjs`
 * and drop the branch in dashboard/reports.gjs.
 */
export default class ManageReports extends Component {
  @tracked allKeys = [];
  @tracked providers = [];
  @tracked search = "";
  @tracked nextCursor = null;
  @tracked hasMore = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked applying = false;
  list = new ToggleableOrderedList({ cap: VISIBLE_CAP });

  itemsByKey = new Map();

  toggleDisabled = (row) => this.list.toggleDisabled(row.key);

  /** Only an enabled row takes part in the order; the rest keep their slots. */
  isMovable = (row) => row.enabled;

  /** Keeps the row's own class and its enabled modifier on the row element. */
  rowClass = (row) =>
    row.enabled
      ? "manageable-row-list__row --enabled"
      : "manageable-row-list__row";

  /** Names a row wherever the list speaks about it: the handle, the menu, the announcement. */
  rowLabel = (row) => row.title;

  constructor() {
    super(...arguments);
    this.load();
  }

  get enabledRows() {
    return this.list.enabledOrder
      .map((key) => this.itemsByKey.get(key))
      .filter(Boolean);
  }

  get allRows() {
    return this.allKeys.map((key) => this.itemsByKey.get(key)).filter(Boolean);
  }

  get disabledRows() {
    const enabled = this.list.enabledKeys;
    return this.allRows.filter((row) => !enabled.has(row.key));
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

  get visibleRows() {
    return [
      ...this.filteredEnabledRows.map((row) => ({ ...row, enabled: true })),
      ...this.disabledRows.map((row) => ({ ...row, enabled: false })),
    ];
  }

  get lastEnabledIndex() {
    return this.filteredEnabledRows.length - 1;
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
      this.list.enabledOrder = enabled.map((item) => item.key);
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
    this.list.toggle(row.key);
  }

  @action
  handleMove({ proposedToItems }) {
    this.list.reorderVisible(
      proposedToItems.filter((row) => row.enabled).map((row) => row.key)
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

  <template>
    <DModal
      @title={{i18n "admin.dashboard.reports_section.modal.title"}}
      @closeModal={{@closeModal}}
      class="manage-reports has-search manageable-row-list"
    >

      <:belowModalTitle>
        <span class="manageable-row-list__counter">
          {{i18n
            "admin.dashboard.reports_section.modal.counter"
            count=this.list.enabledOrder.length
            max=VISIBLE_CAP
          }}
        </span>
      </:belowModalTitle>

      <:belowHeader>
        <div class="manageable-row-list__search-wrapper">
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

        {{#if this.visibleRows.length}}
          <DReorderableList
            class="manageable-row-list__list"
            @disabled={{not this.list.reorderable}}
            @items={{this.visibleRows}}
            @key="key"
            @label={{this.rowLabel}}
            @listLabel={{i18n "admin.dashboard.reports_section.modal.title"}}
            @movable={{this.isMovable}}
            @onMove={{this.handleMove}}
            @rowClass={{this.rowClass}}
          >
            <:row as |row|>
              <ManageableRowListItemReorderable
                @ariaLabelPrefix={{ARIA_LABEL_PREFIX}}
                @row={{row}}
                @toggleDisabled={{this.toggleDisabled row}}
                @onToggle={{this.toggle}}
              />
            </:row>
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
        <p class="manageable-row-list__footer-note">
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
