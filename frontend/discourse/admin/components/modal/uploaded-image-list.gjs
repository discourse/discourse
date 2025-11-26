import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import ImagesUploader from "discourse/admin/components/images-uploader";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class UploadedImageList extends Component {
  @trackedArray
  images = this.args.model.value?.length
    ? this.args.model.value.split("|")
    : [];

  @action
  remove(url, event) {
    event.preventDefault();
    removeValueFromArray(this.images, url);
  }

  @action
  uploadDone({ url }) {
    addUniqueValueToArray(this.images, url);
  }

  @action
  close() {
    this.args.model.changeValue(this.images.join("|"));
    this.args.closeModal();
  }

  <template>
    <DModal
      class="uploaded-image-list"
      @title={{i18n @model.title}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="selectable-avatars">
          {{#each this.images as |image|}}
            <a
              href
              class="selectable-avatar"
              {{on "click" (fn this.remove image)}}
            >
              {{boundAvatarTemplate image "huge"}}
              <span class="selectable-avatar__remove">{{icon
                  "circle-xmark"
                }}</span>
            </a>
          {{else}}
            <p>{{i18n "admin.site_settings.uploaded_image_list.empty"}}</p>
          {{/each}}
        </div>
      </:body>
      <:footer>
        <DButton @action={{this.close}} @label="close" />
        <ImagesUploader
          @uploading={{this.uploading}}
          @done={{this.uploadDone}}
          class="pull-right"
        />
      </:footer>
    </DModal>
  </template>
}
