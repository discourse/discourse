import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UploadPlaceholderNodeView extends Component {
  @service("app-events") appEvents;

  @tracked progress = 0;
  #progressEvent;

  constructor() {
    super(...arguments);
    this.args.dom?.classList.add("upload-placeholder", "--file");
    if (this.args.dom) {
      this.args.dom.dataset.uploadId = this.args.node.attrs.fileId;
    }
    this.#progressEvent = `composer:upload-progress:${this.args.node.attrs.fileId}`;
    this.appEvents.on(this.#progressEvent, this, this.onProgress);
    this.args.onSetup?.(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(this.#progressEvent, this, this.onProgress);
  }

  onProgress(percentage) {
    this.progress = percentage;
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  get filename() {
    return this.args.node.attrs.filename;
  }

  @action
  cancel(event) {
    event.preventDefault();
    event.stopPropagation();
    this.appEvents.trigger("composer:cancel-upload", {
      fileId: this.args.node.attrs.fileId,
    });
  }

  <template>
    <span class="upload-placeholder__icon">{{icon "file"}}</span>
    <span class="upload-placeholder__filename">{{this.filename}}</span>
    <span class="upload-placeholder__progress">{{this.progress}}%</span>
    <button
      class="upload-placeholder__cancel btn-transparent no-text"
      title={{i18n "cancel"}}
      aria-label={{i18n "cancel"}}
      contenteditable="false"
      {{on "click" this.cancel}}
    >{{icon "xmark"}}</button>
  </template>
}
