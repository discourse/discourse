import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";

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

export default ActivityCell;
