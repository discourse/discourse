import BaseField from "./da-base-field";
import { hash } from "@ember/helper";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import TagChooser from "select-kit/components/tag-chooser";

export default class TagsField extends BaseField {
  <template>
    <section class="field tags-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <TagChooser
            @tags={{@field.metadata.value}}
            @options={{hash allowAny=false disabled=@field.isDisabled}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
