import SortableColumn from "./sortable-column";

const RepliesCell = <template>
  <SortableColumn
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="replies"
    @number="true"
    @order="posts"
    @sortable={{@sortable}}
  />
</template>;

export default RepliesCell;
