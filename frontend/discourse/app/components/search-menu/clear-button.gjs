import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <a
    aria-label={{i18n "search.clear_search"}}
    class="clear-search"
    href
    title={{i18n "search.clear_search"}}
    {{on "click" @clearSearch}}
  >
    {{dIcon "xmark"}}
  </a>
</template>
