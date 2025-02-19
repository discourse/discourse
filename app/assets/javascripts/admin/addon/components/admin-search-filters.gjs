import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { i18n } from "discourse-i18n";

const AdminSearchFilters = <template>
  <div class="admin-search-filters">
    {{#each @types as |type|}}
      <span class={{(concat "admin-search-filters__" type)}}>
        {{i18n (concat "admin.search.result_types." type) count=2}}
        <DToggleSwitch
          @state={{get @typeFilters type}}
          {{on "click" (fn @toggleTypeFilter type)}}
        />
      </span>
    {{/each}}
  </div>
</template>;

export default AdminSearchFilters;
