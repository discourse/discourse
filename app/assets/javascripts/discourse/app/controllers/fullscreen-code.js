import { afterRender } from "discourse-common/utils/decorators";
import Modal from "discourse/controllers/modal";
import highlightSyntax from "discourse/lib/highlight-syntax";
import CodeblockButtons from "discourse/lib/codeblock-buttons";

export default Modal.extend({
  onShow() {
    this._applyCodeblockButtons();
  },

  onClose() {
    this.codeBlockButtons.cleanup();
  },

  @afterRender
  _applyCodeblockButtons() {
    const modalElement = document.querySelector(".modal-body");

    highlightSyntax(modalElement, this.siteSettings, this.session);

    this.codeBlockButtons = new CodeblockButtons({
      showFullscreen: false,
      showCopy: true,
    });
    this.codeBlockButtons.attachToGeneric(modalElement);
  },
});
