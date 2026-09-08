import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import { trustHTML } from "@ember/template";
import { bind } from "discourse/lib/decorators";
import {
  autoTrackedArray,
  resettableTracked,
} from "discourse/lib/tracked-tools";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FormTemplateFieldUpload extends Component {
  @service appEvents;

  @resettableTracked uploadValue = this.args.value || "";
  @autoTrackedArray uploadedFiles = [];
  fileUploadElementId = `${dasherize(this.args.id.toString())}-uploader`;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: this.args.id,
    type: "composer",
    uploadDone: this.uploadDone,
  });

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:replace-text", this, this.handleReplaceText);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:replace-text", this, this.handleReplaceText);
  }

  get uploadStatusLabel() {
    return this.uppyUpload.uploading || this.uppyUpload.processing
      ? "form_templates.upload_field.uploading"
      : "form_templates.upload_field.upload";
  }

  get disabled() {
    return this.uppyUpload.uploading || this.uppyUpload.processing;
  }

  @action
  handleReplaceText(oldVal, newVal) {
    if (!this.uploadValue?.includes(oldVal)) {
      return;
    }

    this.uploadValue = this.uploadValue.replace(oldVal, newVal ?? "");

    if (!newVal) {
      this.uploadedFiles = this.uploadedFiles.filter((file) => {
        return !oldVal.includes(file.short_url);
      });
    }

    schedule("afterRender", () => {
      this.args.onChange?.();
    });
  }

  /**
   * The validation from PickFilesButton._filesPicked, where acceptedFormatsOverride
   * is validated and displays a message, happens after the upload is complete.
   *
   * Overriding this method allows us to validate the file before the upload
   *
   * @param file
   * @returns {boolean}
   */
  isUploadedFileAllowed(file) {
    // same logic from PickFilesButton._hasAcceptedExtensionOrType
    const fileTypes = this.args.attributes.file_types;
    const extension = file.name.split(".").pop();

    return (
      !fileTypes ||
      fileTypes.includes(`.${extension}`) ||
      fileTypes.includes(file.type)
    );
  }

  @bind
  uploadDone(upload) {
    // If re-uploading, clear the existing file if multiple aren't allowed
    if (!this.args.attributes.allow_multiple && this.uploadValue) {
      this.uploadedFiles = [];
      this.uploadValue = "";
    }

    this.uploadedFiles.push(upload);

    const uploadMarkdown = this.buildMarkdown(upload);
    if (this.uploadValue && this.uppyUpload.allowMultipleFiles) {
      // multiple file upload
      this.uploadValue = `${this.uploadValue}\n${uploadMarkdown}`;
    } else {
      // single file upload
      this.uploadValue = uploadMarkdown;
    }

    next(this, () => {
      this.args.onChange(this.uploadValue);
      document
        .querySelector(`input[name="${this.args.id}"]`)
        ?.dispatchEvent(new Event("input", { bubbles: true }));
    });
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

  <template>
    <div class="control-group form-template-field" data-field-type="upload">
      {{#if @attributes.label}}
        <label class="form-template-field__label">
          {{@attributes.label}}
          {{#if @validations.required}}
            {{dIcon "asterisk" class="form-template-field__required-indicator"}}
          {{/if}}
        </label>
      {{/if}}

      {{#if @attributes.description}}
        <span class="form-template-field__description">
          {{trustHTML @attributes.description}}
        </span>
      {{/if}}

      <DPickFilesButton
        @acceptedFileTypesString={{@attributes.file_types}}
        @acceptedFormatsOverride={{@attributes.file_types}}
        @allowMultiple={{@attributes.allow_multiple}}
        @fileInputClass="form-template-field__upload"
        @fileInputDisabled={{this.disabled}}
        @fileInputId={{this.fileUploadElementId}}
        @icon="upload"
        @label={{this.uploadStatusLabel}}
        @onFilesPicked={{true}}
        @registerFileInput={{this.uppyUpload.setup}}
        @showButton={{true}}
      />

      {{#if this.uploadedFiles}}
        <ul class="form-template-field__uploaded-files">
          {{#each this.uploadedFiles as |file|}}
            <li>
              {{dIcon "file"}}
              <a
                href={{file.url}}
                rel="noopener noreferrer"
                target="_blank"
              >{{file.file_name}}</a>
              <span>{{file.human_filesize}}</span>
            </li>
          {{/each}}
        </ul>
      {{/if}}

      <input
        aria-hidden="true"
        class="form-template-field__upload-hidden-input"
        name={{@id}}
        required={{if @validations.required "required" ""}}
        tabindex="-1"
        type="text"
        value={{this.uploadValue}}
      />
    </div>
  </template>
}
