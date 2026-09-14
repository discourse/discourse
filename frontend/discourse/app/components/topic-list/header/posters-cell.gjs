import { i18n } from "discourse-i18n";
import SortableColumn from "./sortable-column";

const PostersCell = <template>
  <SortableColumn
    aria-label={{i18n "category.sort_options.posters"}}
    @activeOrder={{@activeOrder}}
    @ascending={{@ascending}}
    @changeSort={{@changeSort}}
    @name="posters"
    @order="posters"
    @screenreaderOnly={{true}}
  />
</template>;

export default PostersCell;
