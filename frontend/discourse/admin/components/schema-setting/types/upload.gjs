import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import FieldInputDescription from "admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "admin/components/schema-setting/types/models";

export default class SchemaSettingTypeUpload extends SchemaSettingTypeModels {
  @tracked value = this.args.value || null;
  type = "upload";

  @action
  onChange(upload) {
    this.value = upload.url;
    return upload.url;
  }

  <template>
    <UppyImageUploader
      @imageUrl={{this.value}}
      @placeholderUrl={{@setting.placeholder}}
      @onUploadDone={{this.onInput}}
      @onUploadDeleted={{fn (mut this.value) null}}
      @type={{this.type}}
      @id={{@setting.schema.name}}
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
