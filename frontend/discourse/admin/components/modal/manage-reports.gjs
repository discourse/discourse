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
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DModal from "discourse/ui-kit/d-modal";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VISIBLE_CAP = 10;
const SEARCH_DEBOUNCE_MS = 200;

class ManageReportsRow extends Component {
  @service site;

  @tracked dragCssClass;
  dragCount = 0;

  isAboveElement(event) {
    const domRect = event.currentTarget.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragStart(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.onDragStart(this.args.row.key);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    if (!this.args.row.enabled) {
      return;
    }
    event.preventDefault();
    if (this.dragCssClass === "dragging") {
      return;
    }
    this.dragCssClass = this.isAboveElement(event)
      ? "drag-above"
      : "drag-below";
  }

  @action
  dragEnter() {
    this.dragCount++;
  }

  @action
  dragLeave() {
    this.dragCount--;
    if (
      this.dragCount === 0 &&
      (this.dragCssClass === "drag-above" || this.dragCssClass === "drag-below")
    ) {
      this.dragCssClass = null;
    }
  }

  @action
  drop(event) {
    if (!this.args.row.enabled) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    this.dragCount = 0;
    const dropAbove = this.isAboveElement(event);
    this.dragCssClass = null;
    this.args.onDrop(this.args.row.key, dropAbove);
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
    this.args.onDragEnd();
  }

  <template>
    <li
      class={{dConcatClass
        "manage-reports__row"
        (if @row.enabled "--enabled")
        this.dragCssClass
      }}
      data-identifier={{@row.key}}
      draggable={{and @row.enabled @reorderable}}
      {{on "dragstart" this.dragStart}}
      {{on "dragover" this.dragOver}}
      {{on "dragenter" this.dragEnter}}
      {{on "dragleave" this.dragLeave}}
      {{on "drop" this.drop}}
      {{on "dragend" this.dragEnd}}
    >

      {{#unless this.site.mobileView}}
        <span class="manage-reports__grip">
          {{dIcon "grip-vertical"}}
        </span>
      {{/unless}}

      {{#if this.site.mobileView}}
        <div class="manage-reports__order-mobile">
          <DButton
            @icon="arrow-up"
            @action={{fn @onMoveUp @row}}
            @disabled={{eq @index 0}}
            @translatedAriaLabel={{i18n
              "admin.dashboard.reports_section.modal.move_up"
              title=@row.title
            }}
            class="manage-reports__arrow btn-transparent"
          />
          <DButton
            @icon="arrow-down"
            @action={{fn @onMoveDown @row}}
            @disabled={{eq @index @lastEnabledIndex}}
            @translatedAriaLabel={{i18n
              "admin.dashboard.reports_section.modal.move_down"
              title=@row.title
            }}
            class="manage-reports__arrow btn-transparent"
          />
        </div>
      {{/if}}

      <div class="manage-reports__row-text">
        <div class="manage-reports__row-heading">
          <span class="manage-reports__title">{{@row.title}}</span>
          {{#if @row.label}}
            {{@row.label}}
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
  @tracked allKeys = [];
  @tracked enabledOrder = [];
  @tracked providers = [];
  @tracked search = "";
  @tracked nextCursor = null;
  @tracked hasMore = false;
  @tracked loading = true;
  @tracked loadingMore = false;
  @tracked applying = false;
  @tracked draggedId = null;
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
    const index = this.enabledOrder.indexOf(row.key);
    if (index <= 0) {
      return;
    }
    const next = [...this.enabledOrder];
    [next[index - 1], next[index]] = [next[index], next[index - 1]];
    this.enabledOrder = next;
  }

  @action
  moveDown(row) {
    const index = this.enabledOrder.indexOf(row.key);
    if (index < 0 || index === this.enabledOrder.length - 1) {
      return;
    }
    const next = [...this.enabledOrder];
    [next[index], next[index + 1]] = [next[index + 1], next[index]];
    this.enabledOrder = next;
  }

  @action
  onDragStart(key) {
    this.draggedId = key;
  }

  @action
  onDrop(targetKey, dropAbove) {
    const fromIndex = this.enabledOrder.indexOf(this.draggedId);
    this.draggedId = null;
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
    this.enabledOrder = next;
  }

  @action
  onDragEnd() {
    this.draggedId = null;
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
              (if this.draggedId "--dragging")
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
                @onDragStart={{this.onDragStart}}
                @onDrop={{this.onDrop}}
                @onDragEnd={{this.onDragEnd}}
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
