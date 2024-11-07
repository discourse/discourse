import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";
import DAG from "discourse/lib/dag";
import { applyValueTransformer } from "discourse/lib/transformer";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

const BulkSelectCell = <template>
  {{#if @bulkSelectEnabled}}
    <th class="bulk-select topic-list-data">
      {{#if @canBulkSelect}}
        <button
          {{on "click" @bulkSelectHelper.toggleBulkSelect}}
          title={{i18n "topics.bulk.toggle"}}
          class="btn-flat bulk-select"
        >
          {{icon "list-check"}}
        </button>
      {{/if}}
    </th>
  {{/if}}
</template>;

const PostersCell = <template>
  {{#if @showPosters}}
    <TopicListHeaderColumn
      @order="posters"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="posters"
      @screenreaderOnly={{true}}
      aria-label={{i18n "category.sort_options.posters"}}
    />
  {{/if}}
</template>;

const RepliesCell = <template>
  <TopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="posts"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="replies"
  />
</template>;

const LikesCell = <template>
  {{#if @showLikes}}
    <TopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="likes"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="likes"
    />
  {{/if}}
</template>;

const OpLikesCell = <template>
  {{#if @showOpLikes}}
    <TopicListHeaderColumn
      @sortable={{@sortable}}
      @number="true"
      @order="op_likes"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="likes"
    />
  {{/if}}
</template>;

const ViewsCell = <template>
  <TopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="views"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="views"
  />
</template>;

const ActivityCell = <template>
  <TopicListHeaderColumn
    @sortable={{@sortable}}
    @number="true"
    @order="activity"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="activity"
  />
</template>;

export function createColumns() {
  const columns = new DAG();
  columns.add("topic-list-before-columns");
  columns.add("bulk-select", BulkSelectCell);
  columns.add("topic");
  columns.add("topic-list-after-main-link");
  columns.add("posters", PostersCell);
  columns.add("replies", RepliesCell);
  columns.add("likes", LikesCell);
  columns.add("op-likes", OpLikesCell);
  columns.add("views", ViewsCell);
  columns.add("activity", ActivityCell);
  columns.add("topic-list-after-columns");
  return columns;
}

export default class TopicListHeader extends Component {
  @service topicTrackingState;

  @cached
  get columns() {
    const self = this;
    const context = {
      get category() {
        return self.topicTrackingState.get("filterCategory");
      },

      get filter() {
        return self.topicTrackingState.get("filter");
      },
    };

    return applyValueTransformer(
      "topic-list-header-columns",
      createColumns(),
      context
    );
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
            @showPosters={{@showPosters}}
            @showLikes={{@showLikes}}
            @showOpLikes={{@showOpLikes}}
          />
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
        {{/if}}
      {{/each}}
    </tr>
  </template>
}
