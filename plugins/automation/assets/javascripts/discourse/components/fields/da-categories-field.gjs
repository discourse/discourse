import Category from "discourse/models/category";
import { action } from "@ember/object";
import BaseField from "./da-base-field";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import CategorySelector from "select-kit/components/category-selector";
import { fn, hash } from "@ember/helper";

export default class CategoriesField extends BaseField {
  <template>
    {{! template-lint-disable no-redundant-fn }}
    <section class="field categories-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <CategorySelector
            @categories={{this.categories}}
            @onChange={{fn this.onChangeCategories}}
            @options={{hash clearable=true disabled=@field.isDisabled}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  get categories() {
    const ids = this.args.field?.metadata?.value || [];
    return ids.map((id) => Category.findById(id)).filter(Boolean);
  }

  @action
  onChangeCategories(categories) {
    this.mutValue(categories.mapBy("id"));
  }
}
