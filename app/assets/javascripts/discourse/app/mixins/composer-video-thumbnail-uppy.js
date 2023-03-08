import Mixin from "@ember/object/mixin";
import ExtendableUploader from "discourse/mixins/extendable-uploader";
import UppyS3Multipart from "discourse/mixins/uppy-s3-multipart";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { warn } from "@ember/debug";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Mixin.create(ExtendableUploader, UppyS3Multipart, {
  dialog: service(),
  uploadRootPath: "/uploads",
  uploadTargetBound: false,
  useUploadPlaceholders: true,

  @bind
  _generateVideoThumbnail() {
    let videos = document.getElementsByClassName("video-container");
    if (!videos) {
      return;
    }

    let video_container = videos[0];
    if (!video_container) {
      return;
    }

    let video = video_container.querySelector("video:first-of-type");
    if (!video) {
      return;
    }

    let video_src = video.getElementsByTagName("source")[0].src;
    let video_sha1 = video_src
      .substring(video_src.lastIndexOf("/") + 1)
      .split(".")[0];

    // Wait for the video element to load, otherwise the canvas will be empty
    video.oncanplay = () => {
      let canvas = document.createElement("canvas");
      let ctx = canvas.getContext("2d");
      let videoHeight, videoWidth;
      videoHeight = video.videoHeight;
      videoWidth = video.videoWidth;
      canvas.width = videoWidth;
      canvas.height = videoHeight;

      ctx.drawImage(video, 0, 0, videoWidth, videoHeight);

      // upload video thumbnail
      canvas.toBlob((blob) => {
        this._uppyInstance = new Uppy({
          id: `screenshot-placeholder`,
          meta: {
            upload_type: `thumbnail`,
            video_sha1,
          },
          autoProceed: true,
        });

        if (this.siteSettings.enable_upload_debug_mode) {
          this._instrumentUploadTimings();
        }

        if (this.siteSettings.enable_direct_s3_uploads) {
          this._useS3MultipartUploads();
        } else {
          this._useXHRUploads();
        }
        this._uppyInstance.use(DropTarget, { target: this.element });

        this._uppyInstance.on("upload", () => {
          this.set("uploading", true);
        });

        this._uppyInstance.on("upload-success", () => {
          this.set("uploading", false);
        });

        this._uppyInstance.on("upload-error", (file, error, response) => {
          let message = I18n.t("wizard.upload_error");
          if (response.body.errors) {
            message = response.body.errors.join("\n");
          }

          this.dialog.alert(message);
          this.set("uploading", false);
        });

        try {
          this._uppyInstance.addFile({
            source: `${this.id} thumbnail`,
            name: video_sha1,
            type: blob.type,
            data: blob,
          });
        } catch (err) {
          warn(`error adding files to uppy: ${err}`, {
            id: "discourse.upload.uppy-add-files-error",
          });
        }
      });
    };
  },

  // This should be overridden in a child component if you need to
  // hook into uppy events and be sure that everything is already
  // set up for _uppyInstance.
  _uppyReady() {},

  _useXHRUploads() {
    this._uppyInstance.use(XHRUpload, {
      endpoint: getURL(`/uploads.json?client_id=${this.messageBus.clientId}`),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
      },
    });
  },
});
