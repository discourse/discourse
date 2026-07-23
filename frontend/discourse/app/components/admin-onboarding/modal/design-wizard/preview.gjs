import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import {
  applyPreviewFonts,
  applyPreviewPalette,
} from "discourse/lib/design-wizard-preview";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const FONT_FACES_LINK_ID = "design-wizard-preview-fonts";
const DECORATIONS_STYLE_ID = "design-wizard-preview-decorations";

export default class DesignWizardPreview extends Component {
  @tracked loading = true;

  frame;

  get previewUrl() {
    const path = this.args.homepage === "categories" ? "/categories" : "/";
    return getURL(`${path}?preview_theme_id=${this.args.themeId}`);
  }

  // loading a second copy of the app inside acceptance tests would fight the
  // test runner, so tests assert on data-preview-url instead
  get frameSrc() {
    return isTesting() ? undefined : this.previewUrl;
  }

  get frameDocument() {
    if (!this.frame?.src) {
      return;
    }

    const doc = this.frame.contentDocument;
    return doc?.body ? doc : undefined;
  }

  @action
  registerFrame(element) {
    this.frame = element;
  }

  @action
  frameNavigating() {
    this.loading = true;
  }

  @action
  async frameLoaded() {
    const doc = this.frameDocument;
    if (!doc) {
      return;
    }

    this.decorateFrame(doc);
    this.applyFonts();
    await this.applyPalette();
    this.loading = false;
  }

  @action
  applyFonts() {
    applyPreviewFonts(this.frameDocument, {
      bodyFont: this.args.bodyFont,
      headingFont: this.args.headingFont,
    });
  }

  @action
  async applyPalette() {
    await applyPreviewPalette(this.frameDocument, {
      paletteId: this.args.palette?.id,
      themeId: this.args.themeId,
    });
  }

  decorateFrame(doc) {
    if (!doc.getElementById(DECORATIONS_STYLE_ID)) {
      const style = doc.createElement("style");
      style.id = DECORATIONS_STYLE_ID;
      style.textContent = ".admin-onboarding-banner { display: none; }";
      doc.head.appendChild(style);
    }

    // the wizard stylesheet carries @font-face rules for every previewable
    // font; the frame's own stylesheets only embed the currently active ones
    if (!doc.getElementById(FONT_FACES_LINK_ID)) {
      const fontFaces = document.querySelector(
        'link[data-target="wizard"], link[data-target="wizard_rtl"]'
      );
      if (fontFaces) {
        const link = doc.createElement("link");
        link.id = FONT_FACES_LINK_ID;
        link.rel = "stylesheet";
        link.href = fontFaces.href;
        doc.head.appendChild(link);
      }
    }
  }

  @action
  shieldScrolled(event) {
    this.frame?.contentWindow?.scrollBy({ top: event.deltaY, left: 0 });
  }

  <template>
    <div class="design-wizard-modal__preview">
      <div class="design-wizard-modal__preview-label">
        {{dIcon "far-eye"}}
        {{i18n "admin_onboarding_banner.design_wizard.preview.label"}}
      </div>
      <div
        class="design-wizard-modal__preview-frame-wrap"
        {{didUpdate this.applyPalette @palette}}
        {{didUpdate this.applyFonts @bodyFont @headingFont}}
      >
        <iframe
          title={{i18n "admin_onboarding_banner.design_wizard.preview.label"}}
          src={{this.frameSrc}}
          data-preview-url={{this.previewUrl}}
          {{didInsert this.registerFrame}}
          {{didUpdate this.frameNavigating this.previewUrl}}
          {{on "load" this.frameLoaded}}
        ></iframe>
        <div
          class="design-wizard-modal__preview-shield"
          {{on "wheel" this.shieldScrolled}}
        ></div>
        {{#if this.loading}}
          <div class="design-wizard-modal__preview-loading">
            <div class="spinner"></div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
