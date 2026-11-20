import { tracked } from "@glimmer/tracking";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import TagChooser from "discourse/select-kit/components/tag-chooser";

export default class SchemaSettingTypeTags extends SchemaSettingTypeModels {
  @tracked
  value = this.args.value?.map((tag) => {
    if (this.args.sendTagIds && typeof tag === "number") {
      return this.args.tagRecords.get(tag) || { id: tag, name: String(tag) };
    }
    return tag;
  });

  type = "tags";

  get tagChooserOption() {
    return {
      allowAny: false,
      maximum: this.max,
    };
  }

  onChange(tags) {
    if (!this.args.sendTagIds) {
      return tags.map((tag) => tag.name);
    }

    return tags.map((tag) => {
      if (typeof tag.id === "number") {
        this.args.tagRecords.set(tag.id, tag);
      }
      return tag.id;
    });
  }

  <template>
    <TagChooser
      class={{if this.validationErrorMessage "--invalid"}}
      @everyTag={{@spec.every_tag}}
      @onChange={{this.onInput}}
      @options={{this.tagChooserOption}}
      @tags={{this.value}}
    />

    <div class="schema-field__input-supporting-text">
      {{#if (and @description (not this.validationErrorMessage))}}
        <FieldInputDescription @description={{@description}} />
      {{/if}}

      {{#if this.validationErrorMessage}}
        <div class="schema-field__input-error">
          {{this.validationErrorMessage}}
        </div>
      {{/if}}
    </div>
  </template>
}
