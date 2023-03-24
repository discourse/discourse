import Component from "@glimmer/component";

import { inject as service } from "@ember/service";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";

export default class extends Component {
  @service siteSettings;

  @tracked loaded = false;

  IMAGE_TYPE = "image";
  VIDEO_TYPE = "video";
  AUDIO_TYPE = "audio";
  ATTACHMENT_TYPE = "attachment";

  get type() {
    if (isImage(this.args.upload.original_filename)) {
      return this.IMAGE_TYPE;
    }

    if (isVideo(this.args.upload.original_filename)) {
      return this.VIDEO_TYPE;
    }

    if (isAudio(this.args.upload.original_filename)) {
      return this.AUDIO_TYPE;
    }

    return this.ATTACHMENT_TYPE;
  }

  get size() {
    const width = this.args.upload.width;
    const height = this.args.upload.height;

    const ratio = Math.min(
      this.siteSettings.max_image_width / width,
      this.siteSettings.max_image_height / height
    );
    return { width: width * ratio, height: height * ratio };
  }

  get imageStyle() {
    if (this.args.upload.dominant_color && !this.loaded) {
      return htmlSafe(`background-color: #${this.args.upload.dominant_color};`);
    }
  }

  @action
  imageLoaded() {
    this.loaded = true;
  }
}
