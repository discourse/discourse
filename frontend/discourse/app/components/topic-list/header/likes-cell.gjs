import SortableColumn from "./sortable-column.gjs";

const LikesCell = <template>
  <SortableColumn
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="likes"
    @number="true"
    @order="likes"
    @sortable={{@sortable}}
  />
</template>;

export default LikesCell;
