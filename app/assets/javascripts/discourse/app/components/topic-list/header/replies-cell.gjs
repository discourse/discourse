import SortableColumn from "./sortable-column";

const RepliesCell = <template>
  <SortableColumn
    @sortable={{@sortable}}
    @number="true"
    @order="posts"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="replies"
  />
</template>;

export default RepliesCell;
