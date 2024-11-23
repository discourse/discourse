import SortableColumn from "./sortable-column";

const OpLikesCell = <template>
  <SortableColumn
    @sortable={{@sortable}}
    @number="true"
    @order="op_likes"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="likes"
  />
</template>;

export default OpLikesCell;
