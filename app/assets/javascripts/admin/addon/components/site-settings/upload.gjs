import Component from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class Upload extends Component {
  @action
  uploadDone(upload) {
    this.set("value", upload.url);
  }

  <template>
    <UppyImageUploader
      @imageUrl={{this.value}}
      @placeholderUrl={{this.setting.placeholder}}
      @onUploadDone={{this.uploadDone}}
      @onUploadDeleted={{fn (mut this.value) null}}
      @additionalParams={{hash for_site_setting=true}}
      @type="site_setting"
      @id={{concat "site-setting-image-uploader-" this.setting.setting}}
    />
  </template>
}
