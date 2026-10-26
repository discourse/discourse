import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class CategoriesField extends BaseField {
  @service siteSettings;

  get categories() {
    const ids = this.args.field?.metadata?.value || [];
    return ids.map((id) => Category.findById(id)).filter(Boolean);
  }

  <template>
    <section class="field categories-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectCategory
              class="category-selector"
              @clearable={{true}}
              @disabled={{@field.isDisabled}}
              @onChange={{this.onChangeCategories}}
              @value={{this.categories}}
            />
          {{else}}
            <CategorySelector
              @categories={{this.categories}}
              @onChange={{this.onChangeCategories}}
              @options={{hash clearable=true disabled=@field.isDisabled}}
            />
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @action
  onChangeCategories(categories) {
    if (isBlank(categories)) {
      this.mutValue(undefined);
      return;
    }

    this.mutValue(categories.map((item) => item.id));
  }
}
