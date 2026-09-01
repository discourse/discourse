import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ManageableRowListItem from "discourse/admin/components/manageable-row-list-item";
import ToggleableOrderedList from "discourse/admin/lib/toggleable-ordered-list";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export const VISIBLE_CAP = 10;
export const SYNTHETIC_KEYS = ["new_members", "returning", "staff"];

const EXCLUDED_AUTO_GROUP_IDS = [0, 3, 4, 5];
const ARIA_LABEL_PREFIX =
  "admin.dashboard.sections.engagement.whos_posting.modal";

export function groupToken(groupId) {
  return `group:${groupId}`;
}

export default class CompareGroups extends Component {
  @service site;

  @tracked search = "";
  @tracked applying = false;
  list = new ToggleableOrderedList({ cap: VISIBLE_CAP, minSelected: 1 });

  rowsByKey = new Map();

  toggleDisabled = (row) => this.list.toggleDisabled(row.key);

  constructor() {
    super(...arguments);
    this.buildRows();

    const currentTokens = this.args.model?.currentTokens ?? [];
    this.list.enabledOrder = currentTokens.filter((key) =>
      this.rowsByKey.has(key)
    );
  }

  get enabledRows() {
    return this.list.enabledOrder
      .map((key) => this.rowsByKey.get(key))
      .filter(Boolean);
  }

  get disabledRows() {
    const enabled = this.list.enabledKeys;
    return [...this.rowsByKey.values()].filter((row) => !enabled.has(row.key));
  }

  get filteredDisabledRows() {
    const query = this.search.trim().toLowerCase();
    if (!query) {
      return this.disabledRows;
    }
    return this.disabledRows.filter((row) =>
      (row.title ?? "").toLowerCase().includes(query)
    );
  }

  get visibleRows() {
    return [
      ...this.enabledRows.map((row) => ({ ...row, enabled: true })),
      ...this.filteredDisabledRows.map((row) => ({ ...row, enabled: false })),
    ];
  }

  get lastEnabledIndex() {
    return this.enabledRows.length - 1;
  }

  buildRows() {
    SYNTHETIC_KEYS.forEach((key) => {
      this.rowsByKey.set(key, {
        key,
        title: i18n(`admin.dashboard.sections.engagement.whos_posting.${key}`),
        description: i18n(
          `admin.dashboard.sections.engagement.whos_posting.modal.descriptions.${key}`
        ),
      });
    });

    (this.site.groups ?? [])
      .filter((group) => !EXCLUDED_AUTO_GROUP_IDS.includes(group.id))
      .forEach((group) => {
        const key = groupToken(group.id);
        this.rowsByKey.set(key, { key, title: group.full_name || group.name });
      });
  }

  @action
  updateSearch(event) {
    this.search = event.target.value;
  }

  @action
  toggle(row) {
    this.list.toggle(row.key);
  }

  @action
  moveUp(row) {
    this.list.moveUp(row.key);
  }

  @action
  moveDown(row) {
    this.list.moveDown(row.key);
  }

  @action
  onDragStart(key) {
    this.list.onDragStart(key);
  }

  @action
  onDrop(targetKey, dropAbove) {
    this.list.onDrop(targetKey, dropAbove);
  }

  @action
  onDragEnd() {
    this.list.onDragEnd();
  }

  @action
  apply() {
    this.applying = true;
    this.args.model?.onApply?.(this.list.enabledOrder);
    this.args.closeModal?.();
  }

  <template>
    <DModal
      @title={{i18n
        "admin.dashboard.sections.engagement.whos_posting.modal.title"
      }}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="compare-groups has-search manageable-row-list"
    >

      <:belowModalTitle>
        <span class="manageable-row-list__counter">
          {{i18n
            "admin.dashboard.sections.engagement.whos_posting.modal.counter"
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
              "admin.dashboard.sections.engagement.whos_posting.modal.search_placeholder"
            }}
          />
        </div>
      </:belowHeader>

      <:body>
        <ul
          class={{dConcatClass
            "manageable-row-list__list"
            (if this.list.draggedId "--dragging")
            (if this.list.reorderable "--reorderable")
          }}
        >
          {{#each this.visibleRows key="key" as |row index|}}
            <ManageableRowListItem
              @ariaLabelPrefix={{ARIA_LABEL_PREFIX}}
              @row={{row}}
              @index={{index}}
              @lastEnabledIndex={{this.lastEnabledIndex}}
              @reorderable={{this.list.reorderable}}
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
      </:body>

      <:footer>
        {{#if @model.footerNote}}
          <p class="manageable-row-list__footer-note">{{@model.footerNote}}</p>
        {{/if}}
        <div class="compare-groups__footer-actions">
          <DButton
            @label="js.cancel_value"
            @action={{@closeModal}}
            class="btn-transparent compare-groups__cancel"
          />
          <DButton
            @label="admin.dashboard.sections.engagement.whos_posting.modal.apply"
            @action={{this.apply}}
            @disabled={{this.applying}}
            @isLoading={{this.applying}}
            class="btn-primary compare-groups__apply"
          />
        </div>
      </:footer>
    </DModal>
  </template>
}
