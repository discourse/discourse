import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

const CategoryNameFields = <template>
  <PluginOutlet
    @name="category-name-fields-details"
    @outletArgs={{hash category=@category}}
  >
    <section class="field category-name-fields">
      {{#unless @category.isUncategorizedCategory}}
        <section class="field-item">
          <label>{{i18n "category.name"}}</label>
          <input
            type="text"
            class="category-name"
            maxlength="50"
            placeholder={{i18n "category.name_placeholder"}}
            value={{@category.name}}
            {{on "input" @category.setName}}
          />
        </section>
      {{/unless}}
      <section class="field-item">
        <label>{{i18n "category.slug"}}</label>
        <input
          type="text"
          maxlength="255"
          placeholder={{i18n "category.slug_placeholder"}}
          value={{@category.slug}}
          {{on "input" @category.setSlug}}
        />
      </section>
    </section>
  </PluginOutlet>
</template>;

export default CategoryNameFields;
