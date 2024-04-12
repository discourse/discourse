import { hash } from "@ember/helper";
import CategoryChooser from "select-kit/components/category-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class CategoryField extends BaseField {
  <template>
    <section class="field category-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <CategoryChooser
            @value={{@field.metadata.value}}
            @onChange={{this.mutValue}}
            @options={{hash clearable=true disabled=@field.isDisabled}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
