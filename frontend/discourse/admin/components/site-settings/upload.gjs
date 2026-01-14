/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { includes } from "discourse/truth-helpers";

const BACKGROUND_SIZE_COVER = ["welcome_banner_image"];

export default class Upload extends Component {
  @action
  uploadDone(upload) {
    this.set("value", upload.url);
  }

  <template>
    <UppyImageUploader
      @imageUrl={{this.value}}
      @placeholderUrl={{this.setting.placeholder}}
      @previewSize={{if
        (includes BACKGROUND_SIZE_COVER this.setting.setting)
        "cover"
      }}
      @onUploadDone={{this.uploadDone}}
      @onUploadDeleted={{fn (mut this.value) null}}
      @additionalParams={{hash for_site_setting=true}}
      @type="site_setting"
      @id={{concat "site-setting-image-uploader-" this.setting.setting}}
      @disabled={{@disabled}}
    />
  </template>
}
