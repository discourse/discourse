import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ImagesUploader from "admin/components/images-uploader";

export default class UploadedImageList extends Component {
  @tracked
  images = this.args.model.value?.length
    ? this.args.model.value.split("|")
    : [];

  @action
  remove(url, event) {
    event.preventDefault();
    this.images.removeObject(url);
  }

  @action
  uploadDone({ url }) {
    this.images.addObject(url);
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
