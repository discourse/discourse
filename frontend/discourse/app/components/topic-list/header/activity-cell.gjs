import SortableColumn from "./sortable-column";

const ActivityCell = <template>
  <SortableColumn
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="activity"
    @number="true"
    @order="activity"
    @sortable={{@sortable}}
  />
</template>;

export default ActivityCell;
