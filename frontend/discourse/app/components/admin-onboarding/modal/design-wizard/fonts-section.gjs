import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  DEFAULT_TEXT_SIZES,
  MAIN_FONTS,
  MORE_FONTS,
} from "discourse/admin/lib/constants";
import DMenu from "discourse/float-kit/components/d-menu";
import { fontClass } from "discourse/lib/design-wizard-preview";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class DesignWizardFontsSection extends Component {
  get baseMoreFontsLabel() {
    return this.#moreFontsLabel(this.args.bodyFont);
  }

  get headingMoreFontsLabel() {
    return this.#moreFontsLabel(this.args.headingFont);
  }

  #moreFontsLabel(selectedKey) {
    const font = MORE_FONTS.find((moreFont) => moreFont.key === selectedKey);
    return (
      font?.name ??
      i18n("admin_onboarding_banner.design_wizard.fonts.more_fonts")
    );
  }

  @action
  async selectMoreFont(onSelect, fontKey, dMenu) {
    await dMenu.close();
    onSelect(fontKey);
  }

  <template>
    <div class="design-wizard-modal__font-group">
      <h4 class="design-wizard-modal__font-group-label">
        {{i18n "admin_onboarding_banner.design_wizard.fonts.base_font"}}
      </h4>
      <div class="design-wizard-modal__font-cards">
        {{#each MAIN_FONTS as |font|}}
          <button
            type="button"
            class="design-wizard-modal__font-card
              {{fontClass font.key}}
              {{if (eq font.key @bodyFont) '--selected'}}"
            {{on "click" (fn @onSelectBodyFont font.key)}}
          >
            {{font.name}}
          </button>
        {{/each}}
      </div>
      <DMenu
        @identifier="design-wizard-more-base-fonts"
        @translatedLabel={{this.baseMoreFontsLabel}}
        @icon="angle-down"
        @triggerClass="btn-default design-wizard-modal__more-fonts"
        @modalForMobile={{true}}
      >
        <:content as |dMenu|>
          <DDropdownMenu
            class="design-wizard-modal__more-fonts-list"
            as |dropdown|
          >
            {{#each MORE_FONTS as |font|}}
              <dropdown.item>
                <DButton
                  @action={{fn
                    this.selectMoreFont
                    @onSelectBodyFont
                    font.key
                    dMenu
                  }}
                  @translatedLabel={{font.name}}
                  class="btn-flat {{fontClass font.key}}"
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>

    <div class="design-wizard-modal__font-group">
      <h4 class="design-wizard-modal__font-group-label">
        {{i18n "admin_onboarding_banner.design_wizard.fonts.heading_font"}}
      </h4>
      <div class="design-wizard-modal__font-cards">
        {{#each MAIN_FONTS as |font|}}
          <button
            type="button"
            class="design-wizard-modal__font-card
              {{fontClass font.key}}
              {{if (eq font.key @headingFont) '--selected'}}"
            {{on "click" (fn @onSelectHeadingFont font.key)}}
          >
            {{font.name}}
          </button>
        {{/each}}
      </div>
      <DMenu
        @identifier="design-wizard-more-heading-fonts"
        @translatedLabel={{this.headingMoreFontsLabel}}
        @icon="angle-down"
        @triggerClass="btn-default design-wizard-modal__more-fonts"
        @modalForMobile={{true}}
      >
        <:content as |dMenu|>
          <DDropdownMenu
            class="design-wizard-modal__more-fonts-list"
            as |dropdown|
          >
            {{#each MORE_FONTS as |font|}}
              <dropdown.item>
                <DButton
                  @action={{fn
                    this.selectMoreFont
                    @onSelectHeadingFont
                    font.key
                    dMenu
                  }}
                  @translatedLabel={{font.name}}
                  class="btn-flat {{fontClass font.key}}"
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>

    <div class="design-wizard-modal__font-group">
      <h4 class="design-wizard-modal__font-group-label">
        {{i18n "admin_onboarding_banner.design_wizard.fonts.default_text_size"}}
      </h4>
      <div class="design-wizard-modal__text-sizes">
        {{#each DEFAULT_TEXT_SIZES as |textSize|}}
          <button
            type="button"
            class="design-wizard-modal__text-size
              {{if (eq textSize @defaultTextSize) '--selected'}}"
            data-text-size={{textSize}}
            {{on "click" (fn @onSelectDefaultTextSize textSize)}}
          >
            {{textSize}}
          </button>
        {{/each}}
      </div>
    </div>
  </template>
}
