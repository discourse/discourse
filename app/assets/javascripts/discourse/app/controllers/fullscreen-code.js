import Controller from "@ember/controller";
import { afterRender } from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import highlightSyntax from "discourse/lib/highlight-syntax";
import CodeblockButtons from "discourse/lib/codeblock-buttons";

export default Controller.extend(ModalFunctionality, {
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
