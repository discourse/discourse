import { concat, fn, get } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const AdminSearchFilters = <template>
  <div class="admin-search__filters">
    {{#each @types as |type|}}
      <span class={{concat "admin-search__filter --" type}}>
        <DButton
          class={{concatClass
            "btn-small admin-search__filter-item"
            (if (get @typeFilters type) "is-active")
          }}
          @translatedLabel={{i18n
            (concat "admin.search.result_types." type)
            count=2
          }}
          @icon={{if (get @typeFilters type) "check" "far-circle"}}
          @action={{fn @toggleTypeFilter type}}
        />
      </span>
    {{/each}}
  </div>
</template>;

export default AdminSearchFilters;
