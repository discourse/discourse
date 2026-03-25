import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const NestedSortSelector = <template>
  <div class="nested-sort-selector">
    <span class="nested-sort-selector__label">{{i18n
        "nested_replies.sort.label"
      }}</span>
    <DButton
      class={{concatClass
        "btn-flat nested-sort-selector__option"
        (if (eq @current "top") "nested-sort-selector__option--active")
      }}
      @action={{fn @onChange "top"}}
      @translatedLabel={{i18n "nested_replies.sort.top"}}
    />
    <DButton
      class={{concatClass
        "btn-flat nested-sort-selector__option"
        (if (eq @current "new") "nested-sort-selector__option--active")
      }}
      @action={{fn @onChange "new"}}
      @translatedLabel={{i18n "nested_replies.sort.new"}}
    />
    <DButton
      class={{concatClass
        "btn-flat nested-sort-selector__option"
        (if (eq @current "old") "nested-sort-selector__option--active")
      }}
      @action={{fn @onChange "old"}}
      @translatedLabel={{i18n "nested_replies.sort.old"}}
    />
  </div>
</template>;

export default NestedSortSelector;
