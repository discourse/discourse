import SortableColumn from "./sortable-column";

const OpLikesCell = <template>
  <SortableColumn
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="likes"
    @number="true"
    @order="op_likes"
    @sortable={{@sortable}}
  />
</template>;

export default OpLikesCell;
