import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { i18n } from "discourse-i18n";

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

  <template>
    <DModal
      @title={{i18n "copy_codeblock.view_code"}}
      @closeModal={{this.closeModal}}
      {{didInsert this.applyCodeblockButtons}}
      class="fullscreen-code-modal -max"
    >
      <:body>
        <pre>
          <code
            class={{@model.codeClasses}}
          >{{@model.code}}</code>
        </pre>
      </:body>
    </DModal>
  </template>
}
