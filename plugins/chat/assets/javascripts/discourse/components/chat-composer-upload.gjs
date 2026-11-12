import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { getURLWithCDN } from "discourse/lib/get-url";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatComposerUpload extends Component {
  @service capabilities;

  registerPreview = modifier((element) =>
    this.args.registerPreview?.({
      type: this.isVideo ? "video" : "image",
      element,
      alt: this.fileName,
    })
  );

  #localPreviewUrl = null;
  @tracked _previewFailed = false;

  constructor() {
    super(...arguments);

    const data = this.args.upload?.data;
    if (!this.args.isDone && data instanceof Blob && this.isMedia) {
      this.#localPreviewUrl = URL.createObjectURL(data);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.#localPreviewUrl) {
      URL.revokeObjectURL(this.#localPreviewUrl);
    }
  }

  get fileName() {
    return this.args.isDone
      ? this.args.upload.original_filename
      : this.args.upload.fileName;
  }

  get isImage() {
    return isImage(this.fileName);
  }

  get isVideo() {
    return isVideo(this.fileName);
  }

  get isMedia() {
    return this.isImage || this.isVideo;
  }

  get previewImageSrc() {
    return this.#localPreviewUrl ?? getURLWithCDN(this.args.upload?.url);
  }

  get previewVideoSrc() {
    const url =
      this.#localPreviewUrl ??
      getURLWithCDN(
        this.args.upload?.optimized_video?.url ?? this.args.upload?.url
      );

    // Safari only paints the first frame when a time fragment is set
    return this.capabilities.isIOS || this.capabilities.isSafari
      ? `${url}#t=0.001`
      : url;
  }

  get hasPreview() {
    return (
      this.isMedia &&
      !this._previewFailed &&
      Boolean(this.args.isDone || this.#localPreviewUrl)
    );
  }

  // files the browser cannot decode (e.g. HEIC outside Safari) fall back to the icon
  @action
  handlePreviewError() {
    this._previewFailed = true;
  }

  <template>
    {{#if @upload}}
      <div
        class={{dConcatClass
          "chat-composer-upload"
          (if this.isImage "chat-composer-upload--image")
          (if this.isVideo "chat-composer-upload--video")
          (if this.hasPreview "chat-composer-upload--with-preview")
          (unless @isDone "chat-composer-upload--in-progress")
        }}
      >
        {{#if this.hasPreview}}
          <DButton
            class="btn-transparent preview chat-composer-upload__preview-btn"
            @action={{@onPreview}}
            @translatedAriaLabel={{i18n
              "chat.preview_upload"
              filename=this.fileName
            }}
          >
            {{#if this.isImage}}
              <img
                alt=""
                class="preview-img"
                src={{this.previewImageSrc}}
                {{on "error" this.handlePreviewError}}
                {{this.registerPreview}}
              />
            {{else}}
              <video
                class="preview-video"
                muted
                playsinline
                preload="metadata"
                src={{this.previewVideoSrc}}
                {{on "error" this.handlePreviewError}}
                {{this.registerPreview}}
              ></video>
            {{/if}}
          </DButton>
          {{#if this.isVideo}}
            {{dIcon "play" class="preview-video__badge"}}
          {{/if}}
        {{else}}
          <div class="preview">
            {{#if this.isImage}}
              {{dIcon "far-image"}}
            {{else if this.isVideo}}
              {{dIcon "file-video"}}
            {{else if (isAudio this.fileName)}}
              {{dIcon "file-audio"}}
            {{else}}
              {{dIcon "file-lines"}}
            {{/if}}
          </div>
        {{/if}}

        <span class="data">
          {{#unless this.hasPreview}}
            <div class="top-data">
              <span class="file-name">{{this.fileName}}</span>
            </div>
          {{/unless}}

          <div class="bottom-data">
            {{#if @isDone}}
              {{#unless this.isMedia}}
                <span class="extension-pill">{{@upload.extension}}</span>
              {{/unless}}
            {{else}}
              {{#unless this.hasPreview}}
                {{#if @upload.processing}}
                  <span class="processing">{{i18n "processing"}}</span>
                {{else}}
                  <span class="uploading">{{i18n "uploading"}}</span>
                {{/if}}
              {{/unless}}

              <progress
                class="upload-progress"
                id="file"
                max="100"
                value={{@upload.progress}}
              ></progress>
            {{/if}}
          </div>
        </span>

        <DButton
          class="btn-flat chat-composer-upload__remove-btn"
          @action={{@onCancel}}
          @icon="xmark"
          @title="chat.remove_upload"
        />
      </div>
    {{/if}}
  </template>
}
