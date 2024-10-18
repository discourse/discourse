import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import PickFilesButton from "discourse/components/pick-files-button";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";
import { bind } from "discourse-common/utils/decorators";
import ChatComposerUpload from "./chat-composer-upload";

export default class ChatComposerUploads extends Component {
  @service siteSettings;
  @service site;
  @service mediaOptimizationWorker;
  @service chatStateManager;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "chat-composer-uploader",
    type: "chat-composer",
    useMultipartUploadsIfAvailable: true,

    uploadDropTargetOptions: {
      target: this.args.uploadDropZone || document.body,
    },

    uppyReady: () => {
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
    },

    uploadDone: (upload) => {
      this.uploads.push(upload);
      this._triggerUploadsChanged();
    },
  });

  constructor() {
    super(...arguments);
    this.args.composerInputEl?.addEventListener(
      "paste",
      this._pasteEventListener
    );
  }

  @cached
  get uploads() {
    this.uppyUpload.cancelAllUploads();
    return new TrackedArray(this.args.existingUploads);
  }

  get inProgressUploads() {
    return this.uppyUpload.inProgressUploads;
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.args.composerInputEl?.removeEventListener(
      "paste",
      this._pasteEventListener
    );

    this.uppyUpload.teardown();
  }

  get showUploadsContainer() {
    return this.uploads.length > 0 || this.inProgressUploads.length > 0;
  }

  @action
  cancelUploading(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
    this.removeUpload(upload);
  }

  @action
  cancelAllUploads() {
    this.uppyUpload.uppyWrapper.uppyInstance?.cancelAll();
  }

  @action
  removeUpload(upload) {
    this.uploads.splice(this.uploads.indexOf(upload), 1);
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

  onProgressUploadsChanged() {
    this._triggerUploadsChanged(this.uploads, {
      inProgressUploadsCount: this.inProgressUploads?.length,
    });
  }

  _triggerUploadsChanged() {
    this.args.onUploadChanged?.(this.uploads, {
      inProgressUploadsCount: this.inProgressUploads?.length,
    });
  }

  <template>
    <div class="chat-composer-uploads">
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
        @fileInputId={{@fileUploadElementId}}
        @allowMultiple={{true}}
        @registerFileInput={{this.uppyUpload.setup}}
        @fileInputClass="hidden-upload-field"
      />
    </div>
  </template>
}
