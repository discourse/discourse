import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";

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

export default ViewsCell;
