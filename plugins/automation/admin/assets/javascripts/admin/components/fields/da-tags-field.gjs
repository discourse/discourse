import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TagsField extends BaseField {
  @action
  onChangeTags(tags) {
    if (isBlank(tags)) {
      tags = undefined;
    } else {
      tags = tags.map((t) => (typeof t === "string" ? t : t.name));
    }

    this.mutValue(tags);
  }

  <template>
    <section class="field tags-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <TagChooser
            @everyTag={{true}}
            @onChange={{this.onChangeTags}}
            @options={{hash allowAny=false disabled=@field.isDisabled}}
            @tags={{readonly @field.metadata.value}}
            @unlimitedTagCount={{true}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
