import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import $ from "jquery";
import DButton from "discourse/components/d-button";
import PickFilesButton from "discourse/components/pick-files-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { getURLWithCDN } from "discourse/lib/get-url";
import lightbox from "discourse/lib/lightbox";
import { authorizesOneOrMoreExtensions, isVideo } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

// Args: id, type, imageUrl, placeholderUrl, additionalParams, onUploadDone, onUploadDeleted, disabled, allowVideo, previewSize
export default class UppyImageUploader extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked imageFilesize;
  @tracked imageFilename;
  @tracked imageWidth;
  @tracked imageHeight;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: this.args.id,
    type: this.args.type,
    additionalParams: this.args.additionalParams,
    validateUploadedFilesOptions: this.args.allowVideo
      ? {}
      : { imagesOnly: true },
    uploadDropTargetOptions: () => ({
      target: document.querySelector(
        `#${this.args.id} .uploaded-image-preview`
      ),
    }),
    uploadDone: (upload) => {
      this.imageFilesize = upload.human_filesize;
      this.imageFilename = upload.original_filename;
      this.imageWidth = upload.width;
      this.imageHeight = upload.height;

      this.args.onUploadDone(upload);
    },
  });

  applyLightbox = modifier(() =>
    lightbox(
      document.querySelector(`#${this.args.id}.image-uploader`),
      this.siteSettings
    )
  );

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.siteSettings.experimental_lightbox) {
      window.pswp?.close();
    } else {
      $.magnificPopup?.instance.close();
    }
  }

  get disabled() {
    return (
      this.args.disabled ||
      this.notAllowed ||
      this.uppyUpload?.uploading ||
      this.uppyUpload?.processing
    );
  }

  get computedId() {
    // without a fallback ID this will not be accessible
    return this.args.id ? `${this.args.id}__input` : `${guidFor(this)}__input`;
  }

  get disabledReason() {
    if (this.disabled && this.notAllowed) {
      return i18n("post.errors.no_uploads_authorized");
    }
  }

  get notAllowed() {
    return !authorizesOneOrMoreExtensions(
      this.currentUser?.staff,
      this.siteSettings
    );
  }

  get showingPlaceholder() {
    return !this.args.imageUrl && this.args.placeholderUrl;
  }

  get placeholderStyle() {
    if (isEmpty(this.args.placeholderUrl)) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image: url(${this.args.placeholderUrl})`);
  }

  get imageCdnUrl() {
    if (isEmpty(this.args.imageUrl)) {
      return htmlSafe("");
    }

    return getURLWithCDN(this.args.imageUrl);
  }

  get previewSizeClass() {
    return this.args.previewSize === "cover" ? "--bg-size-cover" : "";
  }

  get backgroundStyle() {
    // Only apply background style for images, not videos
    if (this.isVideoFile) {
      return htmlSafe("");
    }
    return htmlSafe(`background-image: url(${this.imageCdnUrl})`);
  }

  get imageBaseName() {
    if (!isEmpty(this.args.imageUrl)) {
      return this.args.imageUrl.split("/").slice(-1)[0];
    }
  }

  get progressBarStyle() {
    let progress = this.uppyUpload.uploadProgress || 0;
    return htmlSafe(`width: ${progress}%`);
  }

  get acceptedFormats() {
    return this.args.allowVideo ? "image/*,video/*" : "image/*";
  }

  get isVideoFile() {
    return this.args.imageUrl && isVideo(this.args.imageUrl);
  }

  @action
  toggleLightbox() {
    // Only allow lightbox for images, not videos
    if (this.isVideoFile) {
      return;
    }

    const lightboxImage = document.querySelector(`#${this.args.id} a.lightbox`);

    if (!lightboxImage) {
      return;
    }

    if (this.siteSettings.experimental_lightbox) {
      lightbox(lightboxImage, this.siteSettings);
      lightboxImage.click();
    } else {
      $(lightboxImage).magnificPopup("open");
    }
  }

  @action
  handleKeyboardActivation(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault(); // avoid space scrolling the page
      const input = document.getElementById(this.computedId);
      if (input && !this.disabled) {
        input.click();
      }
    }
  }

  <template>
    <div
      id={{@id}}
      class="image-uploader {{if @imageUrl 'has-image' 'no-image'}}"
      ...attributes
    >
      <div
        class={{concatClass
          "uploaded-image-preview input-xxlarge"
          this.previewSizeClass
        }}
        style={{this.backgroundStyle}}
      >
        {{#if this.showingPlaceholder}}
          <div
            class="placeholder-overlay"
            style={{this.placeholderStyle}}
          ></div>
        {{/if}}

        {{#if @imageUrl}}
          {{#if this.isVideoFile}}
            <video
              controls
              preload="metadata"
              style="width: 100%; height: 100%; object-fit: contain; border-radius: 4px;"
            >
              <source src={{this.imageCdnUrl}} />
            </video>
            <div class="meta">
              <span class="informations">
                {{this.imageFilename}}
                {{#if this.imageFilesize}}
                  -
                  {{this.imageFilesize}}
                {{/if}}
              </span>
            </div>
          {{else}}
            <a
              {{this.applyLightbox}}
              href={{this.imageCdnUrl}}
              title={{this.imageFilename}}
              rel="nofollow ugc noopener"
              class="lightbox"
            >
              <div class="meta">
                <span class="informations">
                  {{this.imageWidth}}x{{this.imageHeight}}
                  {{this.imageFilesize}}
                </span>
              </div>
            </a>

            <div class="expand-overlay">
              <DButton
                @action={{this.toggleLightbox}}
                @icon="discourse-expand"
                @title="expand"
                class="btn-default btn-small image-uploader-lightbox-btn"
              />
            </div>
          {{/if}}
        {{else}}
          <div class="image-upload-controls">
            <label
              class="btn btn-transparent
                {{if this.disabled 'disabled'}}
                {{if this.uppyUpload.uploading 'hidden'}}"
              title={{this.disabledReason}}
              for={{this.computedId}}
              tabindex="0"
              {{on "keydown" this.handleKeyboardActivation}}
            >
              {{icon "upload"}}
              <PickFilesButton
                @registerFileInput={{this.uppyUpload.setup}}
                @fileInputDisabled={{this.disabled}}
                @acceptedFormatsOverride={{this.acceptedFormats}}
                @fileInputId={{this.computedId}}
              />
              {{i18n "upload_selector.select_file"}}
            </label>

            <div
              class="progress-status
                {{unless this.uppyUpload.uploading 'hidden'}}"
            >
              <div
                aria-label="{{i18n 'upload_selector.uploading'}}
              {{this.uppyUpload.uploadProgress}}%"
                role="progressbar"
                class="progress-bar-container"
              >
                <div class="progress-bar" style={{this.progressBarStyle}}></div>
              </div>

              <span>
                {{i18n "upload_selector.uploading"}}
                {{this.uppyUpload.uploadProgress}}%
              </span>
            </div>
          </div>
        {{/if}}
      </div>

      {{#if @imageUrl}}
        <div class="image-upload-controls">
          <label
            class="btn btn-default btn-small {{if this.disabled 'disabled'}}"
            title={{this.disabledReason}}
            for={{this.computedId}}
            tabindex="0"
            {{on "keydown" this.handleKeyboardActivation}}
          >
            {{icon "upload"}}
            <PickFilesButton
              @registerFileInput={{this.uppyUpload.setup}}
              @fileInputDisabled={{this.disabled}}
              @acceptedFormatsOverride={{this.acceptedFormats}}
              @fileInputId={{this.computedId}}
            />
            {{i18n "upload_selector.change"}}
          </label>
          <DButton
            @action={{@onUploadDeleted}}
            @icon="trash-can"
            @disabled={{this.disabled}}
            @label="upload_selector.delete"
            class="btn-danger btn-small"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
