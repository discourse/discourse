import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { and, eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDragHandle from "discourse/ui-kit/d-drag-handle";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DModal from "discourse/ui-kit/d-modal";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;
const SEARCH_DEBOUNCE_MS = 200;

class ManageReportsRow extends Component {
  @service site;

  /**
   * A disabled row is not part of the order, so it cannot receive a drop.
   *
   * @returns {boolean} Whether this row accepts the drop.
   */
  @action
  canAcceptDrop() {
    return Boolean(this.args.row.enabled && this.args.reorderable);
  }

  /**
   * Resolves a drop onto this row into a reorder.
   *
   * Rows travel by their stable `key`, never as objects: `visibleRows` can be
   * search-filtered and spreads a fresh copy of each row per render, so an object
   * would not match by identity a moment later.
   *
   * @param {Object} params - The drop payload.
   * @param {Object} params.source - The dragged source, carrying `data.key`.
   * @param {string} params.position - Whether the drop landed before or after.
   */
  @action
  onRowDrop({ source, position }) {
    this.args.onDrop(source.data.key, this.args.row.key, position === "before");
  }

  <template>
    <li
      class={{dConcatClass "manage-reports__row" (if @row.enabled "--enabled")}}
      data-identifier={{@row.key}}
      {{! `disabled` carries what the draggable attribute used to: the library marks
          the host draggable unconditionally, and a disabled row must not look grabbable }}
      {{dDragAndDropSource
        type="dashboard-report"
        data=(hash key=@row.key)
        disabled=(not (and @row.enabled @reorderable))
      }}
      {{dDragAndDropTarget
        accepts="dashboard-report"
        acceptsSelf=false
        canDrop=this.canAcceptDrop
        onDrop=this.onRowDrop
      }}
    >

      {{#unless this.site.mobileView}}
        <DDragHandle
          @label={{i18n
            "admin.dashboard.reports_section.modal.drag_handle"
            title=@row.title
          }}
          class="manage-reports__grip"
        />
      {{/unless}}

      {{! The arrows are the only keyboard path to reorder, so they render on
          every viewport — the pointer drag beside them on desktop is an
          alternative to them, not a replacement. }}
      <DReorderButtons
        @onMoveUp={{fn @onMoveUp @row}}
        @onMoveDown={{fn @onMoveDown @row}}
        @disableUp={{eq @index 0}}
        @disableDown={{eq @index @lastEnabledIndex}}
        @upLabel={{i18n
          "admin.dashboard.reports_section.modal.move_up"
          title=@row.title
        }}
        @downLabel={{i18n
          "admin.dashboard.reports_section.modal.move_down"
          title=@row.title
        }}
        class="manage-reports__arrows"
      />

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
        @state={{@row.enabled}}
        disabled={{@toggleDisabled}}
        aria-label={{i18n
          (if
            @row.enabled
            "admin.dashboard.reports_section.modal.disable"
            "admin.dashboard.reports_section.modal.enable"
          )
          title=@row.title
        }}
        {{on "click" (fn @onToggle @row)}}
      />
    </li>
  </template>
}

export default class ManageReports extends Component {
  @service a11y;

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

  get visibleRows() {
    return [
      ...this.filteredEnabledRows.map((row) => ({ ...row, enabled: true })),
      ...this.disabledRows.map((row) => ({ ...row, enabled: false })),
    ];
  }

  get atCap() {
    return this.enabledOrder.length >= VISIBLE_CAP;
  }

  get reorderable() {
    return this.enabledOrder.length > 1;
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

  @action
  moveUp(row) {
    this.#move(row, -1);
  }

  @action
  moveDown(row) {
    this.#move(row, 1);
  }

  /**
   * Swaps a row with its neighbour in the list as displayed.
   *
   * Resolved against `filteredEnabledRows` rather than against `enabledOrder`,
   * because a search filter hides rows without removing them from the order.
   * Stepping by index in the full order would swap with a hidden neighbour: the
   * stored order would change, an announcement would claim a move, and nothing
   * the user can see would move. The neighbour is then located in the full order
   * by key, so the swap lands on the right pair either way.
   *
   * @param {Object} row - The row to move.
   * @param {number} delta - `-1` to move it up, `1` to move it down.
   */
  #move(row, delta) {
    const visible = this.filteredEnabledRows;
    const visibleIndex = visible.findIndex((item) => item.key === row.key);
    const neighbour = visible[visibleIndex + delta];
    if (visibleIndex < 0 || !neighbour) {
      return;
    }

    const from = this.enabledOrder.indexOf(row.key);
    const to = this.enabledOrder.indexOf(neighbour.key);
    if (from < 0 || to < 0) {
      return;
    }

    const next = [...this.enabledOrder];
    [next[from], next[to]] = [next[to], next[from]];
    this.#reorder(next, row, visibleIndex + delta, visible.length);
  }

  @action
  onDrop(draggedKey, targetKey, dropAbove) {
    const fromIndex = this.enabledOrder.indexOf(draggedKey);
    if (fromIndex < 0) {
      return;
    }

    const targetIndex = this.enabledOrder.indexOf(targetKey);
    if (targetIndex < 0) {
      return;
    }

    let toIndex = dropAbove ? targetIndex : targetIndex + 1;
    if (fromIndex < toIndex) {
      toIndex -= 1;
    }
    if (fromIndex === toIndex) {
      return;
    }

    const next = [...this.enabledOrder];
    const [moved] = next.splice(fromIndex, 1);
    next.splice(toIndex, 0, moved);

    // Where the row lands on screen, which is not `toIndex` while a filter is
    // hiding rows. A reorder cannot change which rows match the filter, only
    // their order, so the visible set is taken from before the move.
    const visibleKeys = new Set(this.filteredEnabledRows.map((row) => row.key));
    const nextVisible = next.filter((key) => visibleKeys.has(key));

    this.#reorder(
      next,
      this.itemsByKey.get(draggedKey),
      nextVisible.indexOf(draggedKey),
      nextVisible.length
    );
  }

  /**
   * Applies a new order and announces where the row landed.
   *
   * Both the arrows and the drag funnel through here, past their own no-op
   * guards, so a move is announced exactly once and a non-move never is.
   *
   * `toIndex` and `total` are counted in the list the user is looking at, which
   * is not the stored order whenever a search filter is hiding rows. Announcing
   * a position from the full order would name a place that is not on screen.
   * Both are required rather than defaulted for that reason: falling back to the
   * stored order is the mistake this exists to prevent.
   *
   * @param {string[]} nextOrder - The new stored order.
   * @param {Object} row - The row that moved.
   * @param {number} toIndex - Its index in the displayed list.
   * @param {number} total - How many rows that list holds.
   */
  #reorder(nextOrder, row, toIndex, total) {
    this.enabledOrder = nextOrder;

    this.a11y.announce(
      i18n("reorder_announcement", {
        label: row.title,
        position: toIndex + 1,
        total,
      })
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

        {{#if this.visibleRows.length}}
          <ul
            class={{dConcatClass
              "manage-reports__list"
              (if this.reorderable "--reorderable")
            }}
          >
            {{#each this.visibleRows key="key" as |row index|}}
              <ManageReportsRow
                @row={{row}}
                @index={{index}}
                @lastEnabledIndex={{this.lastEnabledIndex}}
                @reorderable={{this.reorderable}}
                @toggleDisabled={{this.toggleDisabled row}}
                @onToggle={{this.toggle}}
                @onMoveUp={{this.moveUp}}
                @onMoveDown={{this.moveDown}}
                @onDrop={{this.onDrop}}
              />
            {{/each}}
          </ul>
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
