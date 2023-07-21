import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import highlightSyntax from "discourse/lib/highlight-syntax";
import CodeblockButtons from "discourse/lib/codeblock-buttons";

export default class FullscreenCode extends Component {
  @service siteSettings;
  @service session;

  @action
  closeModal() {
    this.codeBlockButtons.cleanup();
    this.args.closeModal();
  }

  @action
  applyCodeblockButtons(element) {
    const modalElement = element.querySelector(".modal-body");
    highlightSyntax(modalElement, this.siteSettings, this.session);

    this.codeBlockButtons = new CodeblockButtons({
      showFullscreen: false,
      showCopy: true,
    });
    this.codeBlockButtons.attachToGeneric(modalElement);
  }
}
