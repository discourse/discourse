import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";

const LikesCell = <template>
  {{#if @showLikes}}
    <TopicListHeaderColumn
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
