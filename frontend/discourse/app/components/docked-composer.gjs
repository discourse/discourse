import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

// Reusable chat-style "docked" composer. There is deliberately no
// markdown-preview toggle — users who want to see rendered output
// switch to the rich editor via the toolbar's RTE toggle, which is
// effectively a live preview. Skipping preview also avoids the
// cook-on-change CPU cost on every keystroke.
//
// @onSubmit is required; all other args are optional. See the
// styleguide entry (/styleguide → Organisms → Docked Composer) for
// the live API surface.
export default class DockedComposer extends Component {
  @service capabilities;
  @service keyValueStore;
  @service mediaOptimizationWorker;
  @service siteSettings;

  @tracked dragOffset = 0;
  @tracked reply = "";
  @tracked uploads = trackedArray();

  textarea = null;
  uppyUpload = null;
  fileInputEl = null;
  #dragStart = null;
  #rootElement = null;

  #handlePaste = (event) => {
    if (!this.textarea || document.activeElement !== this.textarea) {
      return;
    }
    const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });
    if (!canUpload || canPasteHtml || types.includes("text/plain")) {
      return;
    }
    if (event?.clipboardData?.files?.length) {
      this.uppyUpload?.addFiles([...event.clipboardData.files], {
        pasted: true,
      });
    }
  };

  #handleKeyDown = (event) => {
    if (event.key !== "Enter" || event.isComposing) {
      return;
    }

    const submitOnEnter = this.args.submitOnEnter ?? true;

    if (submitOnEnter) {
      if (
        !event.shiftKey &&
        !event.metaKey &&
        !event.ctrlKey &&
        !event.altKey
      ) {
        event.preventDefault();
        event.stopPropagation();
        this.submit();
      }
    } else {
      if (event.metaKey || event.ctrlKey) {
        event.preventDefault();
        event.stopPropagation();
        this.submit();
      }
    }
  };

  get maxResizeOffset() {
    return this.args.maxResizeOffset ?? null;
  }

  get resizeAriaMax() {
    return this.maxResizeOffset ?? 400;
  }

  get show() {
    return this.args.show ?? true;
  }

  get draftKey() {
    return this.args.draftKey ?? "docked-composer-draft";
  }

  get uploaderId() {
    return (
      this.args.uploaderId ?? `docked-composer-file-uploader-${guidFor(this)}`
    );
  }

  get uploadType() {
    return this.args.uploadType ?? "composer";
  }

  get minLength() {
    return this.args.minLength ?? 1;
  }

  // DEditor's composer-event bus (quote-reply insert, toolbar replace,
  // etc.). Defaults on for real app use; tests can pass false to avoid
  // app-event listener churn in rendering harnesses.
  get composerEvents() {
    return this.args.composerEvents ?? true;
  }

  get inProgressUploads() {
    return this.uppyUpload?.inProgressUploads || [];
  }

  get canSubmit() {
    if (this.args.isSubmitting || this.args.disabled) {
      return false;
    }
    if (this.inProgressUploads.length > 0) {
      return false;
    }
    return (
      this.reply.trim().length >= this.minLength || this.uploads.length > 0
    );
  }

  get submitDisabled() {
    return !this.canSubmit;
  }

  get showUploadsContainer() {
    return this.uploads?.length > 0 || this.inProgressUploads?.length > 0;
  }

  @action
  setupEditor(textManipulation) {
    this.textarea =
      textManipulation?.textarea ??
      // Scope the fallback to this instance's root so multiple docked
      // composers on the same page can't cross-wire.
      this.#rootElement?.querySelector(".d-editor-input") ??
      null;
    if (this.textarea) {
      // capture phase so Enter-to-send wins over ItsATrap / smart-list handlers
      this.textarea.addEventListener("keydown", this.#handleKeyDown, true);
      this.textarea.addEventListener("paste", this.#handlePaste);
    }
  }

  @action
  loadDraft() {
    const saved = this.keyValueStore.get(this.draftKey);
    if (saved) {
      this.reply = saved;
    }
  }

  @action
  persistDraft(value) {
    if (value?.length) {
      this.keyValueStore.set({ key: this.draftKey, value });
    } else {
      this.keyValueStore.remove(this.draftKey);
    }
  }

  @action
  onReplyChange(event) {
    const value = event?.target?.value ?? "";
    this.reply = value;
    this.persistDraft(value);
  }

  @action
  setupContainer(element) {
    this.#rootElement = element;
    this.loadDraft();

    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: this.uploaderId,
      type: this.uploadType,
      useMultipartUploadsIfAvailable: true,
      uppyReady: () => {
        if (this.siteSettings.composer_media_optimization_image_enabled) {
          this.uppyUpload.uppyWrapper.useUploadPlugin(UppyMediaOptimization, {
            optimizeFn: (data, opts) =>
              this.mediaOptimizationWorker.optimizeImage(data, opts),
            runParallel: !this.capabilities.isMobileDevice,
          });
        }
      },
      uploadDone: (upload) => {
        this.uploads.push(upload);
      },
    });
  }

  @action
  teardown() {
    this.textarea?.removeEventListener("keydown", this.#handleKeyDown, true);
    this.textarea?.removeEventListener("paste", this.#handlePaste);
    this.uppyUpload?.teardown();
    this.#rootElement = null;
  }

  @action
  registerFileInput(element) {
    if (!element) {
      return;
    }
    this.fileInputEl = element;
    this.uppyUpload?.setup(element);
  }

  @action
  openFileUpload() {
    this.fileInputEl?.click();
  }

  @action
  addToolbarButtons(toolbar) {
    toolbar.addButton({
      id: "docked-composer-upload",
      group: "insertions",
      icon: "upload",
      title: this.args.uploadTitle ?? "composer.upload_title",
      sendAction: () => this.openFileUpload(),
    });

    this.args.extraToolbarButtons?.(toolbar);
  }

  @action
  removeUpload(upload) {
    this.uploads = trackedArray(this.uploads.filter((u) => u !== upload));
  }

  @action
  cancelUpload(upload) {
    this.uppyUpload?.cancelSingleUpload({ fileId: upload.id });
  }

  @action
  async submit() {
    if (!this.canSubmit || !this.args.onSubmit) {
      return;
    }
    try {
      const result = await this.args.onSubmit({
        raw: this.reply,
        uploads: this.uploads,
        inProgressUploadsCount: this.inProgressUploads.length,
      });
      // Falsy return → don't clear; consumer can short-circuit on
      // validation failure without losing the user's input.
      if (!result) {
        return;
      }
      this.reply = "";
      this.uploads = trackedArray();
      this.persistDraft("");
      schedule("afterRender", () => this.textarea?.focus());
    } catch (error) {
      // Consumers can opt into custom error handling; otherwise we
      // fall back to the generic ajax-error popup for network failures.
      if (this.args.onError) {
        this.args.onError(error);
      } else {
        popupAjaxError(error);
      }
    }
  }

  @action
  focus() {
    this.textarea?.focus();
  }

  @action
  onResizeStart(event) {
    event.preventDefault();
    this.#dragStart = {
      clientY: event.clientY,
      offset: this.dragOffset,
    };
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  @action
  onResizeMove(event) {
    if (!this.#dragStart || !this.#rootElement?.isConnected) {
      return;
    }
    // dragging UP should grow the composer, so invert
    const delta = this.#dragStart.clientY - event.clientY;
    const raw = Math.max(0, this.#dragStart.offset + delta);
    this.dragOffset =
      this.maxResizeOffset != null ? Math.min(this.maxResizeOffset, raw) : raw;
    this.#rootElement.style.setProperty(
      "--docked-composer-drag-offset",
      `${this.dragOffset}px`
    );
  }

  @action
  onResizeKeyDown(event) {
    // Arrow keys nudge height; Home/End snap to bounds. We mirror the
    // dragOffset state so the keyboard interaction stays in sync with
    // pointer drags.
    const STEP = 16;
    const max = this.maxResizeOffset ?? 400;
    let next = this.dragOffset;
    switch (event.key) {
      case "ArrowUp":
        next = Math.min(max, this.dragOffset + STEP);
        break;
      case "ArrowDown":
        next = Math.max(0, this.dragOffset - STEP);
        break;
      case "Home":
        next = 0;
        break;
      case "End":
        next = max;
        break;
      default:
        return;
    }
    event.preventDefault();
    this.dragOffset = next;
    this.#rootElement?.style.setProperty(
      "--docked-composer-drag-offset",
      `${next}px`
    );
  }

  @action
  onResizeEnd(event) {
    if (!this.#dragStart) {
      return;
    }
    this.#dragStart = null;
    event.currentTarget.releasePointerCapture?.(event.pointerId);
  }

  <template>
    {{#if this.show}}
      {{#if @bodyClassName}}
        {{bodyClass @bodyClassName}}
      {{/if}}
      <div
        class={{concatClass
          "docked-composer"
          (if @resizable "docked-composer--resizable")
          @class
        }}
        ...attributes
        {{didInsert this.setupContainer}}
        {{willDestroy this.teardown}}
      >
        {{#if @resizable}}
          <div
            class="docked-composer__resize-handle"
            role="separator"
            aria-orientation="horizontal"
            aria-label={{i18n "composer.resize"}}
            aria-valuenow={{this.dragOffset}}
            aria-valuemin="0"
            aria-valuemax={{this.resizeAriaMax}}
            tabindex="0"
            {{! template-lint-disable no-pointer-down-event-binding }}
            {{on "pointerdown" this.onResizeStart}}
            {{on "pointermove" this.onResizeMove}}
            {{on "pointerup" this.onResizeEnd}}
            {{on "pointercancel" this.onResizeEnd}}
            {{on "keydown" this.onResizeKeyDown}}
          ></div>
        {{/if}}
        <div class="docked-composer__inner">
          <div class="docked-composer__editor">
            <DEditor
              @value={{this.reply}}
              @change={{this.onReplyChange}}
              @onSetup={{this.setupEditor}}
              @extraButtons={{this.addToolbarButtons}}
              @composerEvents={{this.composerEvents}}
              @topicId={{@topicId}}
              @categoryId={{@categoryId}}
              @processPreview={{false}}
              @placeholder={{@placeholder}}
            >
              {{#if (has-block "submit")}}
                {{yield
                  (hash
                    submit=this.submit
                    disabled=this.submitDisabled
                    isSubmitting=@isSubmitting
                  )
                  to="submit"
                }}
              {{else}}
                <DButton
                  @icon="reply"
                  @action={{this.submit}}
                  @disabled={{this.submitDisabled}}
                  @isLoading={{@isSubmitting}}
                  @title={{@submitTitle}}
                  class="docked-composer__submit-btn"
                />
              {{/if}}
            </DEditor>
          </div>

          <input
            type="file"
            id={{this.uploaderId}}
            class="hidden-upload-field"
            multiple="multiple"
            {{didInsert this.registerFileInput}}
          />
        </div>

        {{#if this.showUploadsContainer}}
          <div class="docked-composer__uploads">
            {{#each this.uploads as |upload|}}
              <div class="docked-composer__upload">
                <span class="docked-composer__upload-filename">
                  {{upload.original_filename}}
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn this.removeUpload upload}}
                  class="btn-transparent docked-composer__upload-remove"
                />
              </div>
            {{/each}}
            {{#each this.inProgressUploads as |upload|}}
              <div
                class="docked-composer__upload docked-composer__upload--in-progress"
              >
                <span class="docked-composer__upload-filename">
                  {{upload.fileName}}
                </span>
                <span class="docked-composer__upload-progress">
                  {{upload.progress}}%
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn this.cancelUpload upload}}
                  class="btn-flat docked-composer__upload-cancel"
                />
              </div>
            {{/each}}
          </div>
        {{/if}}

        {{yield}}
      </div>
    {{/if}}
  </template>
}
