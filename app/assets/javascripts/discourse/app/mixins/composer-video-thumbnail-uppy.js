import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import EmberObject from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import Uppy from "@uppy/core";
import XHRUpload from "@uppy/xhr-upload";
import { isVideo } from "discourse/lib/uploads";
import UppyS3Multipart from "discourse/lib/uppy/s3-multipart";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import getUrl from "discourse-common/helpers/get-url";
import I18n from "discourse-i18n";

// It is not ideal that this is a class extending a mixin, but in the case
// where this is needed (a second background uppy uploader on a class that
// already has an uppyInstance) then it is acceptable for now.
//
// Ideally, this would be refactored into an uppy postprocessor and support
// for that would be added to the ExtendableUploader. Generally, we want to
// move away from these Mixins in future.
//
// Video thumbnail is attached to the post/topic here:
//
// https://github.com/discourse/discourse/blob/110a3025dbf5c7205cec498c7d83dc258d994cfe/app/models/post.rb#L1013-L1035
export default class ComposerVideoThumbnailUppy extends EmberObject.extend(
  UppyUploadMixin
) {
  @service dialog;
  @service siteSettings;
  @service session;

  @tracked uploading;

  uploadRootPath = "/uploads";
  uploadTargetBound = false;
  useUploadPlaceholders = true;
  capabilities = null;
  id = "composer-video";
  uploadDone = () => {};

  constructor(owner) {
    super(...arguments);
    this.capabilities = owner.lookup("service:capabilities");
    setOwner(this, owner);
    this.init();
  }

  generateVideoThumbnail(videoFile, uploadUrl, callback) {
    if (!this.siteSettings.video_thumbnails_enabled) {
      return callback();
    }

    if (!isVideo(videoFile.name)) {
      return callback();
    }

    const video = document.createElement("video");
    video.src = URL.createObjectURL(videoFile.data);

    // These attributes are needed for thumbnail generation on mobile.
    // This video tag is not visible, so this is all happening in the background.
    video.autoplay = true;
    video.muted = true;
    video.playsinline = true;

    const videoSha1 = uploadUrl
      .substring(uploadUrl.lastIndexOf("/") + 1)
      .split(".")[0];

    // Wait for the video element to load, otherwise the canvas will be empty.
    // iOS Safari prefers onloadedmetadata over oncanplay. System tests running in Chrome
    // prefer oncanplaythrough.
    const eventName = this.capabilities.isIOS
      ? "onloadedmetadata"
      : "oncanplaythrough";
    video[eventName] = () => {
      const canvas = document.createElement("canvas");
      const ctx = canvas.getContext("2d");

      // A timeout is needed on mobile.
      setTimeout(() => {
        // If dimensions can't be read, abort.
        if (video.videoWidth === 0) {
          return callback();
        }

        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        ctx.drawImage(video, 0, 0, video.videoWidth, video.videoHeight);

        // Detect Empty Thumbnail
        const imageData = ctx.getImageData(
          0,
          0,
          video.videoWidth,
          video.videoHeight
        );
        const data = imageData.data;

        let isEmpty = true;
        for (let i = 0; i < data.length; i += 4) {
          // Check RGB values
          if (data[i] !== 0 || data[i + 1] !== 0 || data[i + 2] !== 0) {
            isEmpty = false;
            break;
          }
        }

        if (!isEmpty) {
          // upload video thumbnail
          canvas.toBlob((blob) => {
            this._uppyInstance = new Uppy({
              id: "video-thumbnail",
              meta: {
                videoSha1,
                upload_type: "thumbnail",
              },
              autoProceed: true,
            });

            if (this.siteSettings.enable_upload_debug_mode) {
              this.uppyUpload.uppyWrapper.debug.instrumentUploadTimings(
                this._uppyInstance
              );
            }

            if (this.siteSettings.enable_direct_s3_uploads) {
              new UppyS3Multipart(getOwner(this), {
                uploadRootPath: this.uploadRootPath,
                uppyWrapper: this.uppyUpload.uppyWrapper,
                errorHandler: this._handleUploadError,
              }).apply(this._uppyInstance);
            } else {
              this._uppyInstance.use(XHRUpload, {
                endpoint:
                  getUrl("/uploads") +
                  ".json?client_id=" +
                  this.messageBus?.clientId,
                headers: () => ({
                  "X-CSRF-Token": this.session.csrfToken,
                }),
              });
            }

            this._uppyInstance.on("upload", () => {
              this.uploading = true;
            });

            this._uppyInstance.on("upload-success", () => {
              this.uploading = false;
              callback();
            });

            this._uppyInstance.on("upload-error", (file, error, response) => {
              let message = I18n.t("wizard.upload_error");
              if (response.body.errors) {
                message = response.body.errors.join("\n");
              }

              // eslint-disable-next-line no-console
              console.error(message);
              this.uploading = false;
              callback();
            });

            try {
              this._uppyInstance.addFile({
                source: `${this.id}-video-thumbnail`,
                name: `${videoSha1}`,
                type: blob.type,
                data: blob,
              });
            } catch (err) {
              warn(`error adding files to uppy: ${err}`, {
                id: "discourse.upload.uppy-add-files-error",
              });
            }
          });
        } else {
          this.uploading = false;
          callback();
        }
      }, 100);
    };

    video.onerror = () => {
      // eslint-disable-next-line no-console
      console.warn(
        "Video could not be loaded or decoded for thumbnail generation"
      );
      callback();
    };
  }
}
