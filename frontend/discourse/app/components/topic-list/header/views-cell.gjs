import SortableColumn from "./sortable-column.gjs";

const ViewsCell = <template>
  <SortableColumn
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="views"
    @number="true"
    @order="views"
    @sortable={{@sortable}}
  />
</template>;

export default ViewsCell;
