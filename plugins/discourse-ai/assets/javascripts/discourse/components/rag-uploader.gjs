import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import helperFn from "discourse/helpers/helper-fn";
import { ajax } from "discourse/lib/ajax";
import { removeValueFromArray } from "discourse/lib/array-tools";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RagUploadProgress from "./rag-upload-progress.gjs";

export default class RagUploader extends Component {
  @service appEvents;

  @tracked term = null;
  @tracked ragIndexingStatuses = null;

  uppyUpload = new UppyUpload(this, {
    id: "discourse-ai-rag-uploader",
    maxFiles: 20,
    type: "discourse_ai_rag_upload",
    uploadUrl:
      "/admin/plugins/discourse-ai/rag-document-fragments/files/upload",
    preventDirectS3Uploads: true,
    uploadDone: (uploadedFile) => {
      const newUpload = uploadedFile.upload;
      newUpload.status = "uploaded";
      newUpload.statusText = i18n("discourse_ai.rag.uploads.uploaded");
      this.#pendingUploads.push(newUpload);
    },
  });

  setupUploader = modifier((element) => {
    this.uppyUpload.setup(element);
  });

  cancelUploadsOnTargetChange = helperFn(() => {
    const targetKey = `${this.#targetName}:${this.args.target?.id}`;

    if (this.#targetKey !== undefined && this.#targetKey !== targetKey) {
      // cancelling writes tracked upload state the template already read
      schedule("afterRender", () => {
        if (this.uppyUpload.inProgressUploads.length > 0) {
          this.uppyUpload.cancelAllUploads();
        }
      });
    }

    this.#targetKey = targetKey;
  });

  loadIndexingStatuses = helperFn(() => {
    const targetId = this.args.target?.id;
    const uploadIds = this.#savedUploads.map((upload) => upload.id).join(",");
    const statusesKey = `${this.#targetName}:${targetId}:${uploadIds}`;

    // @target is replaced on every form change
    if (statusesKey === this.#statusesKey) {
      return;
    }
    this.#statusesKey = statusesKey;

    if (!uploadIds || !targetId) {
      return;
    }

    ajax(
      `/admin/plugins/discourse-ai/rag-document-fragments/files/status.json?target_type=${this.#targetName}&target_id=${targetId}`
    ).then((statuses) => {
      if (this.#statusesKey === statusesKey && !this.isDestroying) {
        this.ragIndexingStatuses = statuses;
      }
    });
  });

  // finished uploads not yet handed to @updateUploads
  #pendingUploads = trackedArray();
  #statusesKey;
  #targetKey;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      this.#allUploadsCompleteEvent,
      this,
      "_updateTargetWithUploads"
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      this.#allUploadsCompleteEvent,
      this,
      "_updateTargetWithUploads"
    );
  }

  get acceptedFileTypes() {
    if (this.args.allowImages) {
      return ".txt,.md,.png,.jpg,.jpeg";
    } else {
      return ".txt,.md,.pdf";
    }
  }

  get filteredUploads() {
    if (!this.term) {
      return this.ragUploads;
    }

    return this.ragUploads.filter((u) => {
      return (
        u.original_filename.toUpperCase().indexOf(this.term.toUpperCase()) > -1
      );
    });
  }

  get ragUploads() {
    return [...this.#savedUploads, ...this.#pendingUploads];
  }

  get #allUploadsCompleteEvent() {
    return `upload-mixin:${this.uppyUpload.config.id}:all-uploads-complete`;
  }

  get #savedUploads() {
    return this.args.target?.rag_uploads ?? [];
  }

  get #targetName() {
    return this.args.targetName || this.args.target?.constructor?.name;
  }

  @action
  submitFiles() {
    this.uppyUpload.openPicker();
  }

  @action
  cancelUploading(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
  }

  @action
  removeUpload(upload) {
    removeValueFromArray(this.#pendingUploads, upload);
    this.args.onRemove(upload);
  }

  _updateTargetWithUploads() {
    this.args.updateUploads(this.ragUploads);
    this.#pendingUploads.length = 0;
  }

  <template>
    <div class="rag-uploader" ...attributes>
      {{this.cancelUploadsOnTargetChange}}
      {{this.loadIndexingStatuses}}

      {{#if @allowImages}}
        <p>{{i18n "discourse_ai.rag.uploads.description_with_images"}}</p>
      {{else}}
        <p>{{i18n "discourse_ai.rag.uploads.description"}}</p>
      {{/if}}

      {{#if this.ragUploads}}
        <div class="rag-uploader__search-input-container">
          <div class="rag-uploader__search-input">
            {{dIcon
              "magnifying-glass"
              class="rag-uploader__search-input__search-icon"
            }}
            <Input
              class="rag-uploader__search-input__input"
              placeholder={{i18n "discourse_ai.rag.uploads.filter"}}
              @value={{this.term}}
            />
          </div>
        </div>
      {{/if}}

      <table class="rag-uploader__uploads-list">
        <tbody>
          {{#each this.filteredUploads as |upload|}}
            <tr>
              <td>
                <span class="rag-uploader__rag-file-icon">{{dIcon
                    "file"
                  }}</span>
                {{upload.original_filename}}
              </td>
              <RagUploadProgress
                @ragIndexingStatuses={{this.ragIndexingStatuses}}
                @upload={{upload}}
              />
              <td class="rag-uploader__remove-file">
                <DButton
                  class="btn-flat"
                  @action={{fn this.removeUpload upload}}
                  @icon="xmark"
                  @title="discourse_ai.rag.uploads.remove"
                />
              </td>
            </tr>
          {{/each}}
          {{#each this.uppyUpload.inProgressUploads as |upload|}}
            <tr>
              <td><span class="rag-uploader__rag-file-icon">{{dIcon
                    "file"
                  }}</span>
                {{upload.original_filename}}</td>
              <td class="rag-uploader__upload-status">
                <div class="spinner small"></div>
                <span>{{i18n "discourse_ai.rag.uploads.uploading"}}
                  {{upload.uploadProgress}}%</span>
              </td>
              <td class="rag-uploader__remove-file">
                <DButton
                  class="btn-flat"
                  @action={{fn this.cancelUploading upload}}
                  @icon="xmark"
                  @title="discourse_ai.rag.uploads.remove"
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>

      <input
        accept={{this.acceptedFileTypes}}
        class="hidden-upload-field"
        multiple="multiple"
        type="file"
        {{this.setupUploader}}
      />
      <DButton
        class="btn-default"
        @action={{this.submitFiles}}
        @icon="plus"
        @label="discourse_ai.rag.uploads.button"
        @title="discourse_ai.rag.uploads.button"
      />
    </div>
  </template>
}
