import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class SettingFieldCategory extends Component {
  @service siteSettings;

  get categoryId() {
    const id = parseInt(this.args.field.value, 10);
    return isNaN(id) ? null : id;
  }

  @action
  onChange(categoryId) {
    this.args.field.set(String(categoryId ?? ""));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-chooser"
          @disabled={{@field.disabled}}
          @emit="ids"
          @multiple={{false}}
          @onChange={{this.onChange}}
          @permission="create"
          @placeholder={{i18n "category.none"}}
          @uncategorized={{true}}
          @value={{this.categoryId}}
        />
      {{else}}
        <CategoryChooser
          @onChange={{this.onChange}}
          @options={{hash
            allowUncategorized=true
            none=true
            disabled=@field.disabled
          }}
          @value={{this.categoryId}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
