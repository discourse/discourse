/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class SchemaSettingTypeUpload extends Component {
  @tracked uploadUrl = this.args.value;

  @action
  uploadDone(upload) {
    this.uploadUrl = upload.url;
    this.args.onChange(upload.url);
  }

  @action
  uploadDeleted() {
    this.uploadUrl = null;
    this.args.onChange(null);
  }

  <template>
    <UppyImageUploader
      @additionalParams={{hash for_site_setting=true}}
      @allowVideo={{true}}
      @id={{concat "schema-field-upload-" @setting.setting "-" @name}}
      @imageUrl={{this.uploadUrl}}
      @onUploadDeleted={{this.uploadDeleted}}
      @onUploadDone={{this.uploadDone}}
      @type="site_setting"
    />

    {{#if @description}}
      <div class="schema-field__input-supporting-text">
        <FieldInputDescription @description={{@description}} />
      </div>
    {{/if}}
  </template>
}
