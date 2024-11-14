import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";

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

export default RepliesCell;
