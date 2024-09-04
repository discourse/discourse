import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { cloneJSON } from "discourse-common/lib/object";
import discourseComputed, { bind } from "discourse-common/utils/decorators";

@classNames("chat-composer-uploads")
export default class ChatComposerUploads extends Component.extend(
  UppyUploadMixin
) {
  @service mediaOptimizationWorker;
  @service chatStateManager;

  id = "chat-composer-uploader";
  type = "chat-composer";
  existingUploads = null;
  uploads = null;
  useMultipartUploadsIfAvailable = true;
  uploadDropZone = null;

  init() {
    super.init(...arguments);
    this.setProperties({
      fileInputSelector: `#${this.fileUploadElementId}`,
    });
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    if (this.inProgressUploads?.length > 0) {
      this._uppyInstance?.cancelAll();
    }

    this.set(
      "uploads",
      this.existingUploads ? cloneJSON(this.existingUploads) : []
    );
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.composerInputEl?.addEventListener("paste", this._pasteEventListener);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.composerInputEl?.removeEventListener(
      "paste",
      this._pasteEventListener
    );
  }

  uploadDone(upload) {
    this.uploads.pushObject(upload);
    this._triggerUploadsChanged();
  }

  @discourseComputed("uploads.length", "inProgressUploads.length")
  showUploadsContainer(uploadsCount, inProgressUploadsCount) {
    return uploadsCount > 0 || inProgressUploadsCount > 0;
  }

  @action
  cancelUploading(upload) {
    this.appEvents.trigger(`upload-mixin:${this.id}:cancel-upload`, {
      fileId: upload.id,
    });
    this.removeUpload(upload);
  }

  @action
  removeUpload(upload) {
    this.uploads.removeObject(upload);
    this._triggerUploadsChanged();
  }

  _uploadDropTargetOptions() {
    return {
      target: this.uploadDropZone || document.body,
    };
  }

  _uppyReady() {
    if (this.siteSettings.composer_media_optimization_image_enabled) {
      this.uppyUpload.uppyWrapper.useUploadPlugin(UppyMediaOptimization, {
        optimizeFn: (data, opts) =>
          this.mediaOptimizationWorker.optimizeImage(data, opts),
        runParallel: !this.site.isMobileDevice,
      });
    }

    this.uppyUpload.uppyWrapper.onPreProcessProgress((file) => {
      const inProgressUpload = this.inProgressUploads.findBy("id", file.id);
      if (!inProgressUpload?.processing) {
        inProgressUpload?.set("processing", true);
      }
    });

    this.uppyUpload.uppyWrapper.onPreProcessComplete((file) => {
      const inProgressUpload = this.inProgressUploads.findBy("id", file.id);
      inProgressUpload?.set("processing", false);
    });
  }

  @bind
  _pasteEventListener(event) {
    if (document.activeElement !== this.composerInputEl) {
      return;
    }

    const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });

    if (!canUpload || canPasteHtml || types.includes("text/plain")) {
      return;
    }

    if (event && event.clipboardData && event.clipboardData.files) {
      this._addFiles([...event.clipboardData.files], { pasted: true });
    }
  }

  onProgressUploadsChanged() {
    this._triggerUploadsChanged(this.uploads, {
      inProgressUploadsCount: this.inProgressUploads?.length,
    });
  }

  _triggerUploadsChanged() {
    this.onUploadChanged?.(this.uploads, {
      inProgressUploadsCount: this.inProgressUploads?.length,
    });
  }
}
