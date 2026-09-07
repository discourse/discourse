import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <a
    class="clear-search"
    aria-label={{i18n "search.clear_search"}}
    title={{i18n "search.clear_search"}}
    href
    {{on "click" @clearSearch}}
  >
    {{dIcon "xmark"}}
  </a>
</template>
