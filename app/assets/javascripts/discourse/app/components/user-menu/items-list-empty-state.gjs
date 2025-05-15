import { i18n } from "discourse-i18n";

const ItemsListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user_menu.generic_no_items"}}
    </span>
  </div>
</template>;

export default ItemsListEmptyState;
