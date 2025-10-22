import EmptyState from "discourse/components/empty-state";
import { i18n } from "discourse-i18n";

const ItemsListEmptyState = <template>
  <EmptyState @title={{i18n "user_menu.generic_no_items"}} />
</template>;

export default ItemsListEmptyState;
