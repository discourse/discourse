import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class FKControlImage extends Component {
  static controlType = "image";
  @tracked imageUrl = this.args.value;

  @action
  setImage(upload) {
    this.args.field.set(upload);
    this.imageUrl = upload?.url;
  }

  @action
  removeImage() {
    this.setImage(undefined);
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
