import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";

export default class FKControlImage extends FKBaseControl {
  static controlType = "image";

  get imageUrl() {
    return isBlank(this.args.field.value) ? null : this.args.field.value;
  }

  @action
  setImage(upload) {
    this.args.field.set(upload);
  }

  @action
  removeImage() {
    this.setImage(null);
  }

  <template>
    <UppyImageUploader
      class="form-kit__control-image no-repeat contain-image"
      @disabled={{@field.disabled}}
      @id="{{@field.id}}-{{@field.name}}"
      @imageUrl={{this.imageUrl}}
      @onUploadDeleted={{this.removeImage}}
      @onUploadDone={{this.setImage}}
      @placeholderUrl={{@placeholderUrl}}
      @type={{@type}}
    />
  </template>
}
