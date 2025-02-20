import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";
import concatClass from "discourse/helpers/concat-class";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";

const AdminSearchFilters = <template>
  <div class="admin-search__filters">
    {{#each @types as |type|}}
      <span class={{concat "admin-search__filter --" type}}>
        <DButton
          @label={{i18n (concat
            "admin.search.result_types." type)
            count=2
          }}
          class={{concatClass
            "btn-small admin-search__filter-item"
            (if (get @typeFilters type) "is-active")
          }}
          @icon={{if (get @typeFilters type) "check" "far-circle"}}
          @action={{fn @toggleTypeFilter type}}
        />
      </span>
    {{/each}}
  </div>
</template>;

export default AdminSearchFilters;
