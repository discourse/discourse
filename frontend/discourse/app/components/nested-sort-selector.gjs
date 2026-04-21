import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const NestedSortSelector = <template>
  <ul
    class="nested-sort-selector nav-pills"
    aria-label={{i18n "nested_replies.sort.label"}}
  >
    <li>
      <button
        type="button"
        class={{if (eq @current "top") "active"}}
        aria-pressed={{if (eq @current "top") "true" "false"}}
        {{on "click" (fn @onChange "top")}}
      >
        {{i18n "nested_replies.sort.top"}}
      </button>
    </li>
    <li>
      <button
        type="button"
        class={{if (eq @current "new") "active"}}
        aria-pressed={{if (eq @current "new") "true" "false"}}
        {{on "click" (fn @onChange "new")}}
      >
        {{i18n "nested_replies.sort.new"}}
      </button>
    </li>
    <li>
      <button
        type="button"
        class={{if (eq @current "old") "active"}}
        aria-pressed={{if (eq @current "old") "true" "false"}}
        {{on "click" (fn @onChange "old")}}
      >
        {{i18n "nested_replies.sort.old"}}
      </button>
    </li>
  </ul>
</template>;

export default NestedSortSelector;
