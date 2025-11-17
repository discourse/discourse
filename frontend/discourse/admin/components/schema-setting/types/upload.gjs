import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class SchemaSettingTypeUpload extends Component {
  @tracked localValue = this.args.value;

  @action
  uploadDone(upload) {
    this.localValue = upload.url;
    this.args.onChange(upload.url);
  }

  @action
  uploadDeleted() {
    this.localValue = null;
    this.args.onChange(null);
  }

  <template>
    <UppyImageUploader
      @imageUrl={{this.localValue}}
      @onUploadDone={{this.uploadDone}}
      @onUploadDeleted={{this.uploadDeleted}}
      @additionalParams={{hash for_site_setting=true}}
      @type="site_setting"
      @id={{concat "schema-field-upload-" @setting.setting}}
      @allowVideo={{true}}
    />
  </template>
}
