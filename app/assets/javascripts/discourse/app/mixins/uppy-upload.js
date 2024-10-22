import { alias, or } from "@ember/object/computed";
import { readOnly } from "@ember/object/lib/computed/computed_macros";
import Mixin from "@ember/object/mixin";
import { getOwner } from "@ember/owner";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { deepMerge } from "discourse-common/lib/object";

export { HUGE_FILE_THRESHOLD_BYTES } from "discourse/lib/uppy/uppy-upload";

/**
 * @deprecated
 *
 * This mixin exists only for backwards-compatibility.
 *
 * New implementations should use `lib/uppy/uppy-upload` directly.
 */
export default Mixin.create({
  uppyUpload: null,

  _uppyInstance: alias("uppyUpload.uppyWrapper.uppyInstance"),
  uploadProgress: readOnly("uppyUpload.uploadProgress"),
  inProgressUploads: readOnly("uppyUpload.inProgressUploads"),
  filesAwaitingUpload: readOnly("uppyUpload.filesAwaitingUpload"),
  cancellable: readOnly("uppyUpload.cancellable"),
  uploadingOrProcessing: or("uppyUpload.uploading", "uppyUpload.processing"),
  fileInputEl: alias("uppyUpload._fileInputEl"),
  allowMultipleFiles: readOnly("uppyUpload.allowMultipleFiles"),

  _addFiles: readOnly("uppyUpload.addFiles"),
  _startUpload: readOnly("uppyUpload.startUpload"),

  // Some places are two-way-binding these properties into parent components
  // so we can't use computed properties as aliases.
  // Instead, we have simple properties, with observers that update them when the underlying properties change.
  uploading: false,
  processing: false,

  init() {
    this.uppyUpload = new UppyUpload(getOwner(this), configShim(this));

    this.addObserver("uppyUpload.uploading", () =>
      this.set("uploading", this.uppyUpload.uploading)
    );
    this.addObserver("uppyUpload.processing", () =>
      this.set("processing", this.uppyUpload.processing)
    );

    this._super();
  },

  didInsertElement() {
    if (this.autoFindInput ?? true) {
      this._fileInputEl = this.element.querySelector(
        this.fileInputSelector || ".hidden-upload-field"
      );
    } else if (!this._fileInputEl) {
      return;
    }
    this.uppyUpload.setup(this._fileInputEl);
    this._super();
  },

  willDestroyElement() {
    this.uppyUpload.teardown();
    this._super();
  },
});

/**
 * Given a component which was written for the old mixin interface,
 * this function will generate a config object which is compatible
 * with the new `lib/uppy/uppy-upload` class.
 */
function configShim(component) {
  return {
    get autoStartUploads() {
      return component.autoStartUploads ?? true;
    },
    get id() {
      return component.id;
    },
    get type() {
      return component.type;
    },
    get uploadRootPath() {
      return component.uploadRootPath || "/uploads";
    },
    get uploadDone() {
      return component.uploadDone.bind(component);
    },
    get validateUploadedFilesOptions() {
      return component.validateUploadedFilesOptions?.() || {};
    },
    get additionalParams() {
      return deepMerge({}, component.additionalParams, component.data);
    },
    get maxFiles() {
      return component.maxFiles;
    },
    get uploadDropTargetOptions() {
      return (
        component._uploadDropTargetOptions?.() || { target: component.element }
      );
    },
    get preventDirectS3Uploads() {
      return component.preventDirectS3Uploads ?? false;
    },
    get useChunkedUploads() {
      return component.useChunkedUploads ?? false;
    },
    get useMultipartUploadsIfAvailable() {
      return component.useMultipartUploadsIfAvailable ?? false;
    },
    get uploadError() {
      return component._handleUploadError?.bind(component);
    },
    get uppyReady() {
      return component._uppyReady?.bind(component);
    },
    onProgressUploadsChanged() {
      component.notifyPropertyChange("inProgressUploads"); // because TrackedArray isn't perfectly compatible with legacy computed properties
      return component.onProgressUploadsChanged?.call(component, ...arguments);
    },
    get uploadUrl() {
      return component.uploadUrl;
    },
    get perFileData() {
      return component._perFileData?.bind(component);
    },
  };
}
