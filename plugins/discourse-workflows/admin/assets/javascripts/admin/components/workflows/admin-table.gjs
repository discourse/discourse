import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const indeterminate = modifier((element, [value]) => {
  element.indeterminate = value;
});

export default class AdminTable extends Component {
  @tracked selectedIds = new Set();

  lastClickedRowIndex = null;

  get hasSelection() {
    return this.selectedIds.size > 0;
  }

  get allSelected() {
    return (
      this.args.items?.length > 0 &&
      this.selectedIds.size === this.args.items.length
    );
  }

  get headerCheckboxState() {
    if (this.selectedIds.size === 0) {
      return "none";
    }
    if (this.selectedIds.size === this.args.items?.length) {
      return "all";
    }
    return "indeterminate";
  }

  @action
  itemId(item) {
    return item[this.args.itemKey ?? "id"];
  }

  @action
  isRowSelected(item) {
    return this.selectedIds.has(this.itemId(item));
  }

  @action
  toggleRowSelection(item, event) {
    const id = this.itemId(item);
    const items = this.args.items;
    const currentIndex = items.findIndex((i) => this.itemId(i) === id);
    const next = new Set(this.selectedIds);

    if (event?.shiftKey && this.lastClickedRowIndex !== null) {
      const from = Math.min(this.lastClickedRowIndex, currentIndex);
      const to = Math.max(this.lastClickedRowIndex, currentIndex);
      for (let i = from; i <= to; i++) {
        next.add(this.itemId(items[i]));
      }
    } else if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }

    this.lastClickedRowIndex = currentIndex;
    this.selectedIds = next;
  }

  @action
  clearSelection() {
    this.selectedIds = new Set();
    this.lastClickedRowIndex = null;
  }

  @action
  toggleAllSelection() {
    if (this.allSelected) {
      this.selectedIds = new Set();
    } else {
      this.selectedIds = new Set(this.args.items.map((i) => this.itemId(i)));
    }
  }

  <template>
    <div class="workflows-admin-table" ...attributes>
      <DConditionalLoadingSpinner @condition={{@isLoading}}>
        {{#if @items.length}}
          {{#if (has-block "toolbar")}}
            <div class="workflows-admin-table__toolbar">
              {{yield
                (hash
                  hasSelection=this.hasSelection
                  selectedIds=this.selectedIds
                  clearSelection=this.clearSelection
                )
                to="toolbar"
              }}
            </div>
          {{/if}}

          <DLoadMore @action={{@loadMore}} @enabled={{@canLoadMore}}>
            <table class="d-table workflows-admin-table__table">
              <thead class="d-table__header">
                <tr class="d-table__row">
                  {{#if @selectable}}
                    <th
                      class="d-table__header-cell workflows-admin-table__checkbox-cell"
                    >
                      <input
                        type="checkbox"
                        checked={{this.allSelected}}
                        {{indeterminate
                          (eq this.headerCheckboxState "indeterminate")
                        }}
                        {{on "change" this.toggleAllSelection}}
                        class="workflows-admin-table__checkbox"
                      />
                    </th>
                  {{/if}}
                  {{yield to="head"}}
                </tr>
              </thead>
              <tbody>
                {{#each @items as |item|}}
                  <tr
                    class={{dConcatClass "d-table__row" @rowClass}}
                    data-item-id={{this.itemId item}}
                  >
                    {{#if @selectable}}
                      <td
                        class="d-table__cell workflows-admin-table__checkbox-cell"
                      >
                        <input
                          type="checkbox"
                          checked={{this.isRowSelected item}}
                          {{on "click" (fn this.toggleRowSelection item)}}
                          class="workflows-admin-table__checkbox"
                        />
                      </td>
                    {{/if}}
                    {{yield item to="row"}}
                  </tr>
                {{/each}}
              </tbody>
            </table>
            <DConditionalLoadingSpinner @condition={{@loadingMore}} />
          </DLoadMore>
        {{else}}
          {{yield to="empty"}}
        {{/if}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
