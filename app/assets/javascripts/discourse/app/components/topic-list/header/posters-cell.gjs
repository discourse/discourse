import { i18n } from "discourse-i18n";
import SortableColumn from "./sortable-column";

const PostersCell = <template>
  <SortableColumn
    @order="posters"
    @activeOrder={{@activeOrder}}
    @changeSort={{@changeSort}}
    @ascending={{@ascending}}
    @name="posters"
    @screenreaderOnly={{true}}
    aria-label={{i18n "category.sort_options.posters"}}
  />
</template>;

export default PostersCell;
