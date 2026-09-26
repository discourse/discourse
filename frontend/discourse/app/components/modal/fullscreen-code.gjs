import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "discourse/lib/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import highlightSyntax from "discourse/lib/highlight-syntax";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import SiteService from "discourse/services/site";
import SiteSettingsService from "discourse/services/site-settings";
import SessionService from "discourse/services/session";

export default class FullscreenCode extends Component {
  @service(() => SiteService) site;
  @service(() => SiteSettingsService) siteSettings;
  @service(() => SessionService) session;

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
      site: this.site,
      showFullscreen: false,
      showCopy: true,
    });
    this.codeBlockButtons.attachToGeneric(modalElement);
  }

  <template>
    <DModal
      class="fullscreen-code-modal --max"
      @closeModal={{this.closeModal}}
      @title={{i18n "copy_codeblock.view_code"}}
      {{didInsert this.applyCodeblockButtons}}
    >
      <:body>
        <PluginOutlet
          @name="fullscreen-codeblock-code"
          @outletArgs={{lazyHash code=@model.code}}
        >
          <pre>
            <code class={{@model.codeClasses}}>{{@model.code}}</code>
          </pre>
        </PluginOutlet>
      </:body>
    </DModal>
  </template>
}
