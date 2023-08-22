import Component from "@ember/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { computed } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { dasherize } from "@ember/string";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";

export default class FormTemplateFieldUpload extends Component.extend(
  UppyUploadMixin
) {
  @tracked uploadValue;
  @tracked uploadComplete = false;
  @tracked uploadedFiles = [];
  @tracked disabled = this.uploading;
  @tracked
  fileUploadElementId = this.attributes?.label
    ? `${dasherize(this.attributes.label)}-uploader`
    : `${this.elementId}-uploader`;
  @tracked fileInputSelector = `#${this.fileUploadElementId}`;
  @tracked id = this.fileUploadElementId;

  @computed("uploading", "uploadValue")
  get uploadStatus() {
    if (!this.uploading && !this.uploadValue) {
      return "upload";
    }

    if (!this.uploading && this.uploadValue) {
      this.uploadComplete = true;
      return "upload";
    }

    return "uploading";
  }

  uploadDone(upload) {
    // If reuploading, clear the existing file
    if (this.uploadComplete) {
      this.uploadedFiles = [];
      this.uploadValue = "";
    }

    const uploadMarkdown = this.buildMarkdown(upload);
    this.uploadedFiles.pushObject(upload);

    if (this.uploadValue && this.allowMultipleFiles) {
      // multiple file upload
      this.uploadValue = `${this.uploadValue}\n${uploadMarkdown}`;
    } else {
      // single file upload
      this.uploadValue = uploadMarkdown;
    }
  }

  buildMarkdown(upload) {
    if (isImage(upload.url)) {
      return `![${upload.file_name}|${upload.width}x${upload.height}](${upload.short_url})`;
    }

    if (isAudio(upload.url)) {
      return `![${upload.file_name}|audio](${upload.short_url})`;
    }

    if (isVideo(upload.url)) {
      return `![${upload.file_name}|video](${upload.short_url})`;
    }

    return `[${upload.file_name}|attachment](${upload.short_url}) (${upload.human_filesize})`;
  }
}
