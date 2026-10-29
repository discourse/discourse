import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class Category extends Component {
  @service siteSettings;

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectCategory
        class="category-chooser"
        @emit="ids"
        @label={{@label}}
        @onChange={{@changeValueCallback}}
        @permission="create"
        @placeholder={{i18n "category.none"}}
        @uncategorized={{true}}
        @value={{@value}}
      />
    {{else}}
      <CategoryChooser
        @onChange={{@changeValueCallback}}
        @options={{hash allowUncategorized=true none=(eq @setting.default "")}}
        @value={{@value}}
      />
    {{/if}}
  </template>
}
