import SortableColumn from "./sortable-column";

const ViewsCell = <template>
  <SortableColumn
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
