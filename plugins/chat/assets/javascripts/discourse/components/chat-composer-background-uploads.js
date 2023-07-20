import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import discourseComputed from "discourse-common/utils/decorators";
import UppyUploadMixin from "discourse/mixins/uppy-upload";

export default Component.extend(UppyUploadMixin, {
  classNames: ["chat-composer-background-uploads"],
  chatApi: service(),
  currentUser: service(),
  mediaOptimizationWorker: service(),
  id: "chat-composer-background-uploader",
  type: "chat-composer",
  uploads: null,
  useMultipartUploadsIfAvailable: true,
  completedUploads: null,

  didInsertElement() {
    this._super(...arguments);
    this.completedUploads = [];
    if (this.uploads) {
      this._addFiles([...this.uploads]);
    }
  },

  uploadDone(upload) {
    this.completedUploads.pushObject(upload);
  },

  @discourseComputed("inProgressUploads.length")
  showUploadsContainer(inProgressUploadsCount) {
    return inProgressUploadsCount > 0;
  },

  @action
  cancelUploading(upload) {
    this.appEvents.trigger(`upload-mixin:${this.id}:cancel-upload`, {
      fileId: upload.id,
    });
    this.removeUpload(upload);
  },

  @action
  removeUpload(upload) {
    this.completedUploads.removeObject(upload);
  },

  _uppyReady() {
    if (this.siteSettings.composer_media_optimization_image_enabled) {
      this._useUploadPlugin(UppyMediaOptimization, {
        optimizeFn: (data, opts) =>
          this.mediaOptimizationWorker.optimizeImage(data, opts),
        runParallel: !this.site.isMobileDevice,
      });
    }

    this._onPreProcessProgress((file) => {
      const inProgressUpload = this.inProgressUploads.findBy("id", file.id);
      if (!inProgressUpload?.processing) {
        inProgressUpload?.set("processing", true);
      }
    });

    this._onPreProcessComplete((file) => {
      const inProgressUpload = this.inProgressUploads.findBy("id", file.id);
      inProgressUpload?.set("processing", false);
    });
  },

  _onAllUploadsComplete() {
    this.chatApi
      .sendMessage(this.channel.id, {
        message: "",
        in_reply_to_id: this.inReplyTo?.id,
        thread_id: this.thread?.id,
        upload_ids: this.completedUploads.mapBy("id"),
      })
      .then(() => {
        this.onBackgroundUploadComplete(this.backgroundUploadId);
      });
  },
});
