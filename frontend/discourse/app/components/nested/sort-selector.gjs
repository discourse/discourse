import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const SortOption = <template>
  <li>
    <button
      type="button"
      class={{if (eq @current @value) "active"}}
      aria-pressed={{if (eq @current @value) "true" "false"}}
      {{on "click" (fn @onChange @value)}}
    >{{@label}}</button>
  </li>
</template>;

const NestedSortSelector = <template>
  <ul
    class="nested-sort-selector nav-pills"
    aria-label={{i18n "nested_replies.sort.label"}}
  >
    <SortOption
      @value="top"
      @label={{i18n "nested_replies.sort.top"}}
      @current={{@current}}
      @onChange={{@onChange}}
    />
    <SortOption
      @value="new"
      @label={{i18n "nested_replies.sort.new"}}
      @current={{@current}}
      @onChange={{@onChange}}
    />
    <SortOption
      @value="old"
      @label={{i18n "nested_replies.sort.old"}}
      @current={{@current}}
      @onChange={{@onChange}}
    />
  </ul>
</template>;

export default NestedSortSelector;
