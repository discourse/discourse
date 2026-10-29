import { hash } from "@ember/helper";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class CategoryField extends BaseField {
  @service siteSettings;

  <template>
    <section class="field category-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectCategory
              class="category-chooser"
              @clearable={{true}}
              @disabled={{@field.isDisabled}}
              @emit="ids"
              @label={{@label}}
              @onChange={{this.mutValue}}
              @permission="create"
              @value={{@field.metadata.value}}
            />
          {{else}}
            <CategoryChooser
              @onChange={{this.mutValue}}
              @options={{hash clearable=true disabled=@field.isDisabled}}
              @value={{@field.metadata.value}}
            />
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
