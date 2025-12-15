import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

// unsaved uploads that haven't been hydrated by the backend yet
// so we need to look them up in the cache
const uploadCache = new Map();

export default class SchemaSettingTypeUpload extends Component {
  @tracked uploadUrl = this.#resolveUploadUrl(this.args.value);

  #resolveUploadUrl(value) {
    if (!value) {
      return null;
    }
    if (Number.isInteger(value)) {
      const cachedUpload = uploadCache.get(value);
      return cachedUpload?.url || null;
    }
    return value;
  }

  @action
  uploadDone(upload) {
    uploadCache.set(upload.id, upload);
    this.uploadUrl = upload.url;
    this.args.onChange(upload.id);
  }

  @action
  uploadDeleted() {
    if (Number.isInteger(this.args.value)) {
      uploadCache.delete(this.args.value);
    }
    this.uploadUrl = null;
    this.args.onChange(null);
  }

  <template>
    <UppyImageUploader
      @imageUrl={{this.uploadUrl}}
      @onUploadDone={{this.uploadDone}}
      @onUploadDeleted={{this.uploadDeleted}}
      @additionalParams={{hash for_site_setting=true}}
      @type="site_setting"
      @id={{concat "schema-field-upload-" @setting.setting "-" @name}}
      @allowVideo={{true}}
    />

    {{#if @description}}
      <div class="schema-field__input-supporting-text">
        <FieldInputDescription @description={{@description}} />
      </div>
    {{/if}}
  </template>
}
