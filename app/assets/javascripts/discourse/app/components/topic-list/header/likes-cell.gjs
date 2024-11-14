import SortableColumn from "./sortable-column";

const LikesCell = <template>
  {{#if @showLikes}}
    <SortableColumn
      @sortable={{@sortable}}
      @number="true"
      @order="likes"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="likes"
    />
  {{/if}}
</template>;

export default LikesCell;
