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
      @imageUrl={{this.uploadUrl}}
      @onUploadDone={{this.uploadDone}}
      @onUploadDeleted={{this.uploadDeleted}}
      @additionalParams={{hash for_site_setting=true}}
      @type="site_setting"
      @id={{concat "schema-field-upload-" @setting.setting}}
      @allowVideo={{true}}
    />

    {{#if @description}}
      <div class="schema-field__input-supporting-text">
        <FieldInputDescription @description={{@description}} />
      </div>
    {{/if}}
  </template>
}
