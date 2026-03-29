import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import { eq } from "discourse/truth-helpers";

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
      <ConditionalLoadingSpinner @condition={{@isLoading}}>
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

          <LoadMore @action={{@loadMore}} @enabled={{@canLoadMore}}>
            <table class="workflows-admin-table__table">
              <thead>
                <tr>
                  {{#if @selectable}}
                    <th class="workflows-admin-table__checkbox-cell">
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
                  <tr>
                    {{#if @selectable}}
                      <td class="workflows-admin-table__checkbox-cell">
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
            <ConditionalLoadingSpinner @condition={{@loadingMore}} />
          </LoadMore>
        {{else}}
          {{yield to="empty"}}
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
