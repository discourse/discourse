import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { getURLWithCDN } from "discourse/lib/get-url";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";
import { eq } from "discourse/truth-helpers";

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

    // Shrink to fit, never blow up small images.
    const ratio = Math.min(
      1,
      this.siteSettings.max_image_width / width,
      this.siteSettings.max_image_height / height
    );

    return {
      width,
      thumb_width: width * ratio,
      height,
      thumb_height: height * ratio,
    };
  }

  get imageUrl() {
    const rawUrl = this.args.upload.thumbnail?.url ?? this.args.upload.url;
    return getURLWithCDN(rawUrl);
  }

  get largeImageUrl() {
    return getURLWithCDN(this.args.upload.url);
  }

  get imageStyle() {
    if (this.args.upload.dominant_color && !this.loaded) {
      return trustHTML(
        `background-color: #${this.args.upload.dominant_color};`
      );
    }
  }

  get videoSourceUrl() {
    const baseUrl =
      this.args.upload.optimized_video?.url ?? this.args.upload.url;
    const finalUrl =
      this.capabilities.isIOS || this.capabilities.isSafari
        ? `${baseUrl}#t=0.001`
        : baseUrl;
    return getURLWithCDN(finalUrl);
  }

  get audioSourceUrl() {
    return getURLWithCDN(this.args.upload.url);
  }

  get attachmentUrl() {
    return getURLWithCDN(this.args.upload.url);
  }

  @action
  imageLoaded() {
    this.loaded = true;
  }

  <template>
    {{#if (eq this.type this.IMAGE_TYPE)}}
      <img
        class="chat-img-upload lightbox"
        data-dominant-color={{@upload.dominant_color}}
        data-download-href={{@upload.short_path}}
        data-large-src={{this.largeImageUrl}}
        data-orig-src={{@upload.short_url}}
        data-target-height={{this.size.height}}
        data-target-width={{this.size.width}}
        height={{this.size.thumb_height}}
        loading="lazy"
        src={{this.imageUrl}}
        style={{this.imageStyle}}
        tabindex="0"
        width={{this.size.thumb_width}}
        {{on "load" this.imageLoaded}}
      />
    {{else if (eq this.type this.VIDEO_TYPE)}}
      <video class="chat-video-upload" controls height="150" preload="metadata">
        <source src={{this.videoSourceUrl}} />
      </video>
    {{else if (eq this.type this.AUDIO_TYPE)}}
      <audio class="chat-audio-upload" controls preload="metadata">
        <source src={{this.audioSourceUrl}} />
      </audio>
    {{else}}
      <a
        class="chat-other-upload"
        data-orig-href={{@upload.short_url}}
        href={{this.attachmentUrl}}
      >
        {{@upload.original_filename}}
      </a>
    {{/if}}
  </template>
}
