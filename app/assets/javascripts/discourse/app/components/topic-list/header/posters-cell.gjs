import i18n from "discourse-common/helpers/i18n";
import SortableColumn from "./sortable-column";

const PostersCell = <template>
  {{#if @showPosters}}
    <SortableColumn
      @order="posters"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="posters"
      @screenreaderOnly={{true}}
      aria-label={{i18n "category.sort_options.posters"}}
    />
  {{/if}}
</template>;

export default PostersCell;
