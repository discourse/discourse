import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
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

  get imageUrl() {
    return isBlank(this.args.value) ? null : this.args.value;
  }

  <template>
    <UppyImageUploader
      @id={{concat @field.id "-" @field.name}}
      @imageUrl={{this.imageUrl}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      @type={{@type}}
      class="form-kit__control-image no-repeat contain-image"
    />
  </template>
}
