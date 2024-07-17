import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class FKControlImage extends Component {
  static controlType = "image";

  @action
  setImage(upload) {
    this.args.field.set(upload);
  }

  @action
  removeImage() {
    this.setImage(undefined);
  }

  <template>
    <UppyImageUploader
      @id={{concat @field.id "-" @field.name}}
      @imageUrl={{readonly @value}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      class="form-kit__control-image no-repeat contain-image"
    />
  </template>
}
