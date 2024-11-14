import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";

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

export default OpLikesCell;
