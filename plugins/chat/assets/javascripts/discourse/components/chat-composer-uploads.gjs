/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import PickFilesButton from "discourse/components/pick-files-button";
import { bind } from "discourse/lib/decorators";
import { cloneJSON } from "discourse/lib/object";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";
import ChatComposerUpload from "discourse/plugins/chat/discourse/components/chat-composer-upload";

@classNames("chat-composer-uploads")
export default class ChatComposerUploads extends Component {
  @service capabilities;
  @service mediaOptimizationWorker;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "chat-composer-uploader",
    type: "chat-composer",
    useMultipartUploadsIfAvailable: true,

    uppyReady: () => {
      if (this.siteSettings.composer_media_optimization_image_enabled) {
        this.uppyUpload.uppyWrapper.useUploadPlugin(UppyMediaOptimization, {
          optimizeFn: (data, opts) =>
            this.mediaOptimizationWorker.optimizeImage(data, opts),
          runParallel: !this.capabilities.isMobileDevice,
        });
      }

      this.uppyUpload.uppyWrapper.onPreProcessProgress((file) => {
        const inProgressUpload = this.inProgressUploads.find(
          (item) => item.id === file.id
        );
        if (!inProgressUpload?.processing) {
          inProgressUpload?.set("processing", true);
        }
      });

      this.uppyUpload.uppyWrapper.onPreProcessComplete((file) => {
        const inProgressUpload = this.inProgressUploads.find(
          (item) => item.id === file.id
        );
        inProgressUpload?.set("processing", false);
      });
    },

    uploadDone: (upload) => {
      this.uploads.pushObject(upload);
      this._triggerUploadsChanged();
    },

    uploadDropTargetOptions: () => ({
      target: this.uploadDropZone || document.body,
    }),

    onProgressUploadsChanged: () => {
      this._triggerUploadsChanged(this.uploads, {
        inProgressUploadsCount: this.inProgressUploads?.length,
      });
    },
  });

  existingUploads = null;
  uploads = null;
  uploadDropZone = null;

  get inProgressUploads() {
    return this.uppyUpload.inProgressUploads;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    if (this.inProgressUploads?.length > 0) {
      this.uppyUpload.uppyWrapper.uppyInstance?.cancelAll();
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

  get showUploadsContainer() {
    return this.get("uploads.length") > 0 || this.inProgressUploads.length > 0;
  }

  @action
  cancelUploading(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
    this.removeUpload(upload);
  }

  @action
  removeUpload(upload) {
    this.uploads.removeObject(upload);
    this._triggerUploadsChanged();
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
      this.uppyUpload.addFiles([...event.clipboardData.files], {
        pasted: true,
      });
    }
  }

  _triggerUploadsChanged() {
    this.onUploadChanged?.(this.uploads, {
      inProgressUploadsCount: this.inProgressUploads?.length,
    });
  }

  <template>
    {{#if this.showUploadsContainer}}
      <div class="chat-composer-uploads-container">
        {{#each this.uploads as |upload|}}
          <ChatComposerUpload
            @upload={{upload}}
            @isDone={{true}}
            @onCancel={{fn this.removeUpload upload}}
          />
        {{/each}}

        {{#each this.inProgressUploads as |upload|}}
          <ChatComposerUpload
            @upload={{upload}}
            @onCancel={{fn this.cancelUploading upload}}
          />
        {{/each}}
      </div>
    {{/if}}

    <PickFilesButton
      @allowMultiple={{true}}
      @fileInputId={{this.fileUploadElementId}}
      @fileInputClass="hidden-upload-field"
      @registerFileInput={{this.uppyUpload.setup}}
    />
  </template>
}
