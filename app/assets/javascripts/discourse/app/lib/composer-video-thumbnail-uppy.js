import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isVideo } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

// Ideally, this would be refactored into an uppy postprocessor and support
// for that would be added to the ExtendableUploader.
//
// Video thumbnail is attached to the post/topic here:
//
// https://github.com/discourse/discourse/blob/110a3025dbf5c7205cec498c7d83dc258d994cfe/app/models/post.rb#L1013-L1035
export default class ComposerVideoThumbnailUppy {
  @service dialog;
  @service siteSettings;
  @service session;
  @service capabilities;

  @tracked _uppyUpload;

  constructor(owner) {
    setOwner(this, owner);
  }

  get uploading() {
    this._uppyUpload.uploading;
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
            this._uppyUpload = new UppyUpload(getOwner(this), {
              id: "video-thumbnail",
              type: "thumbnail",
              additionalParams: {
                videoSha1,
              },
              uploadDone() {
                callback();
              },
            });
            this._uppyUpload.setup();

            this._uppyUpload.uppyWrapper.uppyInstance.on(
              "upload-error",
              (file, error, response) => {
                let message = i18n("wizard.upload_error");
                if (response.body.errors) {
                  message = response.body.errors.join("\n");
                }

                // eslint-disable-next-line no-console
                console.error(message);
                callback();
              }
            );

            try {
              blob.name = `${videoSha1}.png`;
              this._uppyUpload.addFiles(blob);
            } catch (err) {
              warn(`error adding files to uppy: ${err}`, {
                id: "discourse.upload.uppy-add-files-error",
              });
            }
          });
        } else {
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
