import Component from "@glimmer/component";
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
    return isBlank(this.args.field.value) ? null : this.args.field.value;
  }

  <template>
    <UppyImageUploader
      @id="{{@field.id}}-{{@field.name}}"
      @imageUrl={{this.imageUrl}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      @type={{@type}}
      @disabled={{@field.disabled}}
      @placeholderUrl={{@field.args.placeholderUrl}}
      class="form-kit__control-image no-repeat contain-image"
    />
  </template>
}
