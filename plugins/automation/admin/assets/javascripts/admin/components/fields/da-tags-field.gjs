import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import TagChooser from "select-kit/components/tag-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TagsField extends BaseField {
  @action
  onChangeTags(tags) {
    if (isBlank(tags)) {
      tags = undefined;
    }

    this.mutValue(tags);
  }

  <template>
    <section class="field tags-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <TagChooser
            @tags={{readonly @field.metadata.value}}
            @everyTag={{true}}
            @options={{hash allowAny=false disabled=@field.isDisabled}}
            @onChange={{this.onChangeTags}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
