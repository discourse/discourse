import SortableColumn from "./sortable-column";

const OpLikesCell = <template>
  {{#if @showOpLikes}}
    <SortableColumn
      @sortable={{@sortable}}
      @number="true"
      @order="op_likes"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="likes"
    />
  {{/if}}
</template>;

export default OpLikesCell;
