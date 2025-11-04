import { i18n } from "discourse-i18n";

const FilterForMore = <template>
  {{#if @collection.content.shouldShowMoreTip}}
    <div class="filter-for-more">
      {{i18n "select_kit.components.filter_for_more"}}
    </div>
  {{/if}}
</template>;

export default FilterForMore;
