import Component from "@glimmer/component";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";
import TopicBulkSelectDropdown from "discourse/components/topic-list/topic-bulk-select-dropdown";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class TopicListHeaderColumn extends Component {
  get localizedName() {
    if (this.args.forceName) {
      return this.args.forceName;
    }

    return this.args.name ? i18n(this.args.name) : "";
  }

  get sortIcon() {
    return this.args.ascending ? "chevron-up" : "chevron-down";
  }

  get isSorting() {
    return this.args.sortable && this.args.order === this.args.activeOrder;
  }

  get ariaSort() {
    if (!this.isSorting) {
      return false;
    }

    return this.args.ascending ? "ascending" : "descending";
  }

  <template>
    <th
      data-sort-order={{@order}}
      scope="col"
      tabindex={{if @sortable "0"}}
      role={{if @sortable "button"}}
      aria-pressed={{this.isSorting}}
      aria-sort={{this.ariaSort}}
      class={{concatClass
        "topic-list-data"
        @order
        (if @sortable "sortable")
        (if @isSorting "sorting")
        (if @number "num")
      }}
      ...attributes
    >
      {{#if @canBulkSelect}}
        {{#if @showBulkToggle}}
          <button
            title={{i18n "topics.bulk.toggle"}}
            class="btn-flat bulk-select"
          >
            {{icon (if @experimentalTopicBulkActionsEnabled "tasks" "list")}}
          </button>
        {{/if}}

        {{#if @bulkSelectEnabled}}
          <span class="bulk-select-topics">
            {{#if @canDoBulkActions}}
              {{#if @experimentalTopicBulkActionsEnabled}}
                <TopicBulkSelectDropdown
                  @bulkSelectHelper={{@bulkSelectHelper}}
                />
              {{else}}
                <button class="btn btn-icon no-text bulk-select-actions">{{icon
                    "cog"
                  }}&#8203;</button>
              {{/if}}
            {{/if}}

            <button class="btn btn-default bulk-select-all">{{i18n
                "topics.bulk.select_all"
              }}</button>
            <button class="btn btn-default bulk-clear-all">{{i18n
                "topics.bulk.clear_all"
              }}</button>
          </span>
        {{/if}}
      {{/if}}

      {{#unless @bulkSelectEnabled}}
        {{#if this.showTopicsAndRepliesToggle}}
          <NewListHeaderControls
            @current={{@newListSubset}}
            @newRepliesCount={{@newRepliesCount}}
            @newTopicsCount={{@newTopicsCount}}
          />
        {{else}}
          <span>{{this.localizedName}}</span>
        {{/if}}
      {{/unless}}

      {{#if this.isSorting}}
        {{icon this.sortIcon}}
      {{/if}}
    </th>
  </template>
}
