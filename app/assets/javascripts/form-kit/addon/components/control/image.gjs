import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class FkControlImage extends Component {
  @action
  setImage(upload) {
    this.args.setValue(upload.url);
  }

  @action
  removeImage() {
    this.args.setValue(undefined);
  }

  @action
  handleDestroy() {
    this.args.setValue(undefined);
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
