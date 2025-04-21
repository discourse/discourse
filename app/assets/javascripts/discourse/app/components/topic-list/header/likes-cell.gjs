import SortableColumn from "./sortable-column";

const LikesCell = <template>
  <SortableColumn
    @sortable={{@sortable}}
    @number="true"
    @order="likes"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="likes"
  />
</template>;

export default LikesCell;
