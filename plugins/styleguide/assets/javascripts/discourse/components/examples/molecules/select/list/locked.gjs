import { hash } from "@ember/helper";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

const HELD = [2, 12];

const ListLockedExample = <template>
  <div class="select-examples__list-pair">
    <DSelectList
      class="select-examples__tag-list"
      @disabled={{true}}
      @identifier="sg-list-disabled"
      @items={{USER_GROUPS}}
      @labelField="fullName"
      @texts={{hash
        ariaLabel=(i18n "styleguide.sections.select.list_disabled_label")
        searchPlaceholder=(i18n
          "styleguide.sections.select.placeholders.search_groups"
        )
      }}
      @value={{HELD}}
      @virtualized={{false}}
    />
    <DSelectList
      class="select-examples__tag-list"
      @identifier="sg-list-readonly"
      @items={{USER_GROUPS}}
      @labelField="fullName"
      @readonly={{true}}
      @texts={{hash
        ariaLabel=(i18n "styleguide.sections.select.list_readonly_label")
        searchPlaceholder=(i18n
          "styleguide.sections.select.placeholders.search_groups"
        )
      }}
      @value={{HELD}}
      @virtualized={{false}}
    />
  </div>
</template>;

export default ListLockedExample;
