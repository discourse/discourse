import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";
import DAG from "discourse/lib/dag";
import { applyValueTransformer } from "discourse/lib/transformer";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

function createColumns() {
  const columns = new DAG();
  columns.add("topic-list-before-columns");
  columns.add("bulk-select", undefined, { after: "topic-list-before-columns" });
  columns.add("topic", undefined, { after: "bulk-select" });
  columns.add("topic-list-after-main-link", undefined, { after: "topic" });
  columns.add("posters", undefined, { after: "topic-list-after-main-link" });
  columns.add("replies", undefined, { after: "posters" });
  columns.add("likes", undefined, { after: "replies" });
  columns.add("op-likes", undefined, { after: "likes" });
  columns.add("views", undefined, { after: "op-likes" });
  columns.add("activity", undefined, { after: "views" });
  columns.add("topic-list-after-columns", undefined, { after: "activity" });
  return columns;
}

export default class TopicListHeader extends Component {
  @cached
  get columns() {
    return applyValueTransformer("topic-list-header-columns", createColumns());
  }

  <template>
    <tr>
      {{#each (this.columns.resolve) as |entry|}}
        {{#if entry.value}}
          <entry.value
            @sortable={{@sortable}}
            @activeOrder={{@order}}
            @changeSort={{@changeSort}}
            @ascending={{@ascending}}
            @category={{@category}}
            @name={{@listTitle}}
            @bulkSelectEnabled={{@bulkSelectEnabled}}
            @showBulkToggle={{@toggleInTitle}}
            @canBulkSelect={{@canBulkSelect}}
            @canDoBulkActions={{@canDoBulkActions}}
            @showTopicsAndRepliesToggle={{@showTopicsAndRepliesToggle}}
            @newListSubset={{@newListSubset}}
            @newRepliesCount={{@newRepliesCount}}
            @newTopicsCount={{@newTopicsCount}}
            @bulkSelectHelper={{@bulkSelectHelper}}
            @changeNewListSubset={{@changeNewListSubset}}
          />
        {{else if (eq entry.key "bulk-select")}}
          {{#if @bulkSelectEnabled}}
            <th class="bulk-select topic-list-data">
              {{#if @canBulkSelect}}
                <button
                  {{on "click" @bulkSelectHelper.toggleBulkSelect}}
                  title={{i18n "topics.bulk.toggle"}}
                  class="btn-flat bulk-select"
                >
                  {{icon "tasks"}}
                </button>
              {{/if}}
            </th>
          {{/if}}
        {{else if (eq entry.key "topic")}}
          <TopicListHeaderColumn
            @order="default"
            @category={{@category}}
            @activeOrder={{@order}}
            @changeSort={{@changeSort}}
            @ascending={{@ascending}}
            @name={{@listTitle}}
            @bulkSelectEnabled={{@bulkSelectEnabled}}
            @showBulkToggle={{@toggleInTitle}}
            @canBulkSelect={{@canBulkSelect}}
            @canDoBulkActions={{@canDoBulkActions}}
            @showTopicsAndRepliesToggle={{@showTopicsAndRepliesToggle}}
            @newListSubset={{@newListSubset}}
            @newRepliesCount={{@newRepliesCount}}
            @newTopicsCount={{@newTopicsCount}}
            @bulkSelectHelper={{@bulkSelectHelper}}
            @changeNewListSubset={{@changeNewListSubset}}
          />
        {{else if (eq entry.key "posters")}}
          {{#if @showPosters}}
            <TopicListHeaderColumn
              @order="posters"
              @activeOrder={{@order}}
              @changeSort={{@changeSort}}
              @ascending={{@ascending}}
              @name="posters"
              @screenreaderOnly={{true}}
              aria-label={{i18n "category.sort_options.posters"}}
            />
          {{/if}}
        {{else if (eq entry.key "replies")}}
          <TopicListHeaderColumn
            @sortable={{@sortable}}
            @number="true"
            @order="posts"
            @activeOrder={{@order}}
            @changeSort={{@changeSort}}
            @ascending={{@ascending}}
            @name="replies"
          />
        {{else if (eq entry.key "likes")}}
          {{#if @showLikes}}
            <TopicListHeaderColumn
              @sortable={{@sortable}}
              @number="true"
              @order="likes"
              @activeOrder={{@order}}
              @changeSort={{@changeSort}}
              @ascending={{@ascending}}
              @name="likes"
            />
          {{/if}}
        {{else if (eq entry.key "op-likes")}}
          {{#if @showOpLikes}}
            <TopicListHeaderColumn
              @sortable={{@sortable}}
              @number="true"
              @order="op_likes"
              @activeOrder={{@order}}
              @changeSort={{@changeSort}}
              @ascending={{@ascending}}
              @name="likes"
            />
          {{/if}}
        {{else if (eq entry.key "views")}}
          <TopicListHeaderColumn
            @sortable={{@sortable}}
            @number="true"
            @order="views"
            @activeOrder={{@order}}
            @changeSort={{@changeSort}}
            @ascending={{@ascending}}
            @name="views"
          />
        {{else if (eq entry.key "activity")}}
          <TopicListHeaderColumn
            @sortable={{@sortable}}
            @number="true"
            @order="activity"
            @activeOrder={{@order}}
            @changeSort={{@changeSort}}
            @ascending={{@ascending}}
            @name="activity"
          />
        {{/if}}
      {{/each}}
    </tr>
  </template>
}
