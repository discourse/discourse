import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class FKControlImage extends Component {
  @action
  setImage(upload) {
    this.args.set(upload);
  }

  @action
  removeImage() {
    this.setImage(undefined);
  }

  <template>
    <UppyImageUploader
      @id={{concat @field.id "-" @field.name}}
      @imageUrl={{@value}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      class="form-kit__control-image no-repeat contain-image"
    />
  </template>
}
