import { hash } from "@ember/helper";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class CategoryField extends BaseField {
  <template>
    <section class="field category-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <CategoryChooser
            @onChange={{this.mutValue}}
            @options={{hash clearable=true disabled=@field.isDisabled}}
            @value={{@field.metadata.value}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
