import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import highlightSyntax from "discourse/lib/highlight-syntax";

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
    const modalElement = element.querySelector(".d-modal__body");
    highlightSyntax(modalElement, this.siteSettings, this.session);

    this.codeBlockButtons = new CodeblockButtons({
      showFullscreen: false,
      showCopy: true,
    });
    this.codeBlockButtons.attachToGeneric(modalElement);
  }
}
