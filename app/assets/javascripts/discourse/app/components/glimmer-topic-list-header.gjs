import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import GlimmerTopicListHeaderColumn from "./glimmer-topic-list-header-column";

const GlimmerTopicListHeader = <template>
  <PluginOutlet @name="topic-list-header-before" />

  {{#if @bulkSelectEnabled}}
    <th class="bulk-select topic-list-data">
      {{#if @canBulkSelect}}
        <button
          title={{i18n "topics.bulk.toggle"}}
          class="btn-flat bulk-select"
        >
          {{icon (if @experimentalTopicBulkActionsEnabled "tasks" "list")}}
        </button>
      {{/if}}
    </th>
  {{/if}}

  <GlimmerTopicListHeaderColumn
    @order="default"
    @activeOrder={{@order}}
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
  />

  <PluginOutlet @name="topic-list-header-after-main-link" />

  {{#if @showPosters}}
    <GlimmerTopicListHeaderColumn
      @order="posters"
      @activeOrder={{@order}}
      @ascending={{@ascending}}
      aria-label={{i18n "category.sort_options.posters"}}
    />
  {{/if}}

  <GlimmerTopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="posts"
    @activeOrder={{@order}}
    @ascending={{@ascending}}
    @name="replies"
    aria-label={{i18n "sr_replies"}}
  />

  {{#if @showLikes}}
    <GlimmerTopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="likes"
      @activeOrder={{@order}}
      @ascending={{@ascending}}
      @name="likes"
      aria-label={{i18n "sr_likes"}}
    />
  {{/if}}

  {{#if @showOpLikes}}
    <GlimmerTopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="op_likes"
      @activeOrder={{@order}}
      @ascending={{@ascending}}
      @name="likes"
      aria-label={{i18n "sr_op_likes"}}
    />
  {{/if}}

  <GlimmerTopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="views"
    @activeOrder={{@order}}
    @ascending={{@ascending}}
    @name="views"
    aria-label={{i18n "sr_views"}}
  />

  <GlimmerTopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="activity"
    @activeOrder={{@order}}
    @ascending={{@ascending}}
    @name="activity"
    aria-label={{i18n "sr_activity"}}
  />

  <PluginOutlet @name="topic-list-header-after" />
</template>;

export default GlimmerTopicListHeader;
