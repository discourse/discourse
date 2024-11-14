import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";
import TopicBulkSelectDropdown from "discourse/components/topic-list/topic-bulk-select-dropdown";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class SortableColumn extends Component {
  @service router;

  get localizedName() {
    if (this.args.forceName) {
      return this.args.forceName;
    }

    return this.args.name ? i18n(this.args.name) : "";
  }

  get isSorting() {
    return this.args.sortable && this.args.order === this.args.activeOrder;
  }

  get ariaSort() {
    if (this.isSorting) {
      return this.args.ascending ? "ascending" : "descending";
    }
  }

  // TODO: this code probably shouldn't be in all columns
  @action
  bulkSelectAll() {
    this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = true;
    document
      .querySelectorAll("input.bulk-select:not(:checked)")
      .forEach((el) => el.click());
  }

  @action
  bulkClearAll() {
    this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = false;
    document
      .querySelectorAll("input.bulk-select:checked")
      .forEach((el) => el.click());
  }

  @action
  onClick(event) {
    event.preventDefault();
    this.args.changeSort(this.args.order);
  }

  @action
  onKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      this.args.changeSort(this.args.order);
      event.preventDefault();
    }
  }

  @action
  afterBulkActionComplete() {
    return this.router.refresh();
  }

  <template>
    <th
      {{(if @sortable (modifier on "click" this.onClick))}}
      {{(if @sortable (modifier on "keydown" this.onKeyDown))}}
      data-sort-order={{@order}}
      scope="col"
      aria-sort={{this.ariaSort}}
      class={{concatClass
        "topic-list-data"
        @order
        (if @sortable "sortable")
        (if this.isSorting "sorting")
        (if @number "num")
      }}
      ...attributes
    >
      {{#if @canBulkSelect}}
        {{#if @showBulkToggle}}
          <button
            {{on "click" @bulkSelectHelper.toggleBulkSelect}}
            title={{i18n "topics.bulk.toggle"}}
            class="btn-flat bulk-select"
          >
            {{icon "list-check"}}
          </button>
        {{/if}}

        {{#if @bulkSelectEnabled}}
          <span class="bulk-select-topics">
            {{#if @canDoBulkActions}}
              <TopicBulkSelectDropdown
                @bulkSelectHelper={{@bulkSelectHelper}}
                @afterBulkActionComplete={{this.afterBulkActionComplete}}
              />
            {{/if}}

            <button
              {{on "click" this.bulkSelectAll}}
              class="btn btn-default bulk-select-all"
            >{{i18n "topics.bulk.select_all"}}</button>
            <button
              {{on "click" this.bulkClearAll}}
              class="btn btn-default bulk-clear-all"
            >{{i18n "topics.bulk.clear_all"}}</button>
          </span>
        {{/if}}
      {{/if}}

      {{#unless @bulkSelectEnabled}}
        {{#if @showTopicsAndRepliesToggle}}
          <NewListHeaderControls
            @current={{@newListSubset}}
            @newRepliesCount={{@newRepliesCount}}
            @newTopicsCount={{@newTopicsCount}}
            @changeNewListSubset={{@changeNewListSubset}}
          />
        {{else}}
          <span
            class={{if @screenreaderOnly "sr-only"}}
            tabindex={{if @sortable "0"}}
            role={{if @sortable "button"}}
            aria-pressed={{this.isSorting}}
          >
            {{this.localizedName}}
          </span>
        {{/if}}
      {{/unless}}

      {{#if this.isSorting}}
        {{icon (if @ascending "chevron-up" "chevron-down")}}
      {{/if}}
      <PluginOutlet
        @name="topic-list-heading-bottom"
        @outletArgs={{hash name=@name bulkSelectEnabled=@bulkSelectEnabled}}
      />
    </th>
  </template>
}
