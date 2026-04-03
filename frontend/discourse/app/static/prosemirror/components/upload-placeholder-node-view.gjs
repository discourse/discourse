import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UploadPlaceholderNodeView extends Component {
  @service("app-events") appEvents;

  constructor() {
    super(...arguments);
    this.args.dom?.classList.add("upload-placeholder-file");
    if (this.args.dom) {
      this.args.dom.dataset.uploadId = this.args.node.attrs.fileId;
    }
    this.args.onSetup?.(this);
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
    {{icon "file"}}
    {{this.filename}}
    <span class="upload-placeholder__progress">0%</span>
    <span
      class="upload-placeholder__cancel"
      title={{i18n "cancel"}}
      role="button"
      contenteditable="false"
      {{on "click" this.cancel}}
    >&times;</span>
  </template>
}
