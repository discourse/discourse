import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";

export default class ChatUpload extends Component {
  @service siteSettings;
  @service capabilities;

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

  get imageUrl() {
    return this.args.upload.thumbnail?.url ?? this.args.upload.url;
  }

  get imageStyle() {
    if (this.args.upload.dominant_color && !this.loaded) {
      return htmlSafe(`background-color: #${this.args.upload.dominant_color};`);
    }
  }

  get videoSourceUrl() {
    const baseUrl = this.args.upload.url;
    return this.capabilities.isIOS || this.capabilities.isSafari
      ? `${baseUrl}#t=0.001`
      : baseUrl;
  }

  @action
  imageLoaded() {
    this.loaded = true;
  }

  <template>
    {{#if (eq this.type this.IMAGE_TYPE)}}
      <img
        class="chat-img-upload"
        data-orig-src={{@upload.short_url}}
        data-large-src={{@upload.url}}
        height={{this.size.height}}
        width={{this.size.width}}
        src={{this.imageUrl}}
        style={{this.imageStyle}}
        loading="lazy"
        tabindex="0"
        data-dominant-color={{@upload.dominant_color}}
        {{on "load" this.imageLoaded}}
      />
    {{else if (eq this.type this.VIDEO_TYPE)}}
      <video class="chat-video-upload" preload="metadata" height="150" controls>
        <source src={{this.videoSourceUrl}} />
      </video>
    {{else if (eq this.type this.AUDIO_TYPE)}}
      <audio class="chat-audio-upload" preload="metadata" controls>
        <source src={{@upload.url}} />
      </audio>
    {{else}}
      <a
        class="chat-other-upload"
        data-orig-href={{@upload.short_url}}
        href={{@upload.url}}
      >
        {{@upload.original_filename}}
      </a>
    {{/if}}
  </template>
}
