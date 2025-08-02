import SortableColumn from "./sortable-column";

const ActivityCell = <template>
  <SortableColumn
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
