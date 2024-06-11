import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import getURL from "discourse-common/lib/get-url";

export default class FkControlImage extends Component {
  @action
  setImage(upload) {
    if (this.args.onSet) {
      this.args.onSet(upload, { set: this.args.set });
    } else {
      this.args.setValue(getURL(upload.url));
    }
  }

  @action
  removeImage() {
    if (this.args.onUnset) {
      this.args.onUnset({ set: this.args.set });
    } else {
      this.args.setValue(undefined);
    }
  }

  @action
  handleDestroy() {
    this.removeImage();
  }

  <template>
    <UppyImageUploader
      @id={{concat @id "-" @name}}
      @imageUrl={{@value}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      class="d-form-image-input no-repeat contain-image"
      {{willDestroy this.handleDestroy}}
    />
  </template>
}
