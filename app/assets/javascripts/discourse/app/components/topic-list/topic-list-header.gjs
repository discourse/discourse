import { on } from "@ember/modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

const TopicListHeader = <template>
  <tr>
    <PluginOutlet @name="topic-list-header-before" />

    {{#if @bulkSelectEnabled}}
      <th class="bulk-select topic-list-data">
        {{#if @canBulkSelect}}
          <button
            {{on "click" @bulkSelectHelper.toggleBulkSelect}}
            title={{i18n "topics.bulk.toggle"}}
            class="btn-flat bulk-select"
          >
            {{icon (if @experimentalTopicBulkActionsEnabled "tasks" "list")}}
          </button>
        {{/if}}
      </th>
    {{/if}}

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
      @experimentalTopicBulkActionsEnabled={{@experimentalTopicBulkActionsEnabled}}
      @bulkSelectHelper={{@bulkSelectHelper}}
      @changeNewListSubset={{@changeNewListSubset}}
    />

    <PluginOutlet @name="topic-list-header-after-main-link" />

    {{#if @showPosters}}
      <TopicListHeaderColumn
        @order="posters"
        @activeOrder={{@order}}
        @changeSort={{@changeSort}}
        @ascending={{@ascending}}
        aria-label={{i18n "category.sort_options.posters"}}
      />
    {{/if}}

    <TopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="posts"
      @activeOrder={{@order}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="replies"
      aria-label={{i18n "sr_replies"}}
    />

    {{#if @showLikes}}
      <TopicListHeaderColumn
        @sortable={{@sortable}}
        @number="true"
        @order="likes"
        @activeOrder={{@order}}
        @changeSort={{@changeSort}}
        @ascending={{@ascending}}
        @name="likes"
        aria-label={{i18n "sr_likes"}}
      />
    {{/if}}

    {{#if @showOpLikes}}
      <TopicListHeaderColumn
        @sortable={{@sortable}}
        @number="true"
        @order="op_likes"
        @activeOrder={{@order}}
        @changeSort={{@changeSort}}
        @ascending={{@ascending}}
        @name="likes"
        aria-label={{i18n "sr_op_likes"}}
      />
    {{/if}}

    <TopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="views"
      @activeOrder={{@order}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="views"
      aria-label={{i18n "sr_views"}}
    />

    <TopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="activity"
      @activeOrder={{@order}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="activity"
      aria-label={{i18n "sr_activity"}}
    />

    <PluginOutlet @name="topic-list-header-after" />
  </tr>
</template>;

export default TopicListHeader;
