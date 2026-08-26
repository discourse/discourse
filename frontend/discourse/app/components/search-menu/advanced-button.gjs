import DTooltip from "discourse/float-kit/components/d-tooltip";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <DTooltip
    class="show-advanced-search-tooltip"
    @identifier="search-menu-advanced-search"
  >
    <:trigger>
      <DButton
        class="show-advanced-search btn-transparent"
        @action={{@openAdvancedSearch}}
        @icon="sliders"
        @ariaLabel="search.open_advanced"
      />
    </:trigger>
    <:content>
      {{i18n "search.open_advanced"}}
    </:content>
  </DTooltip>
</template>
