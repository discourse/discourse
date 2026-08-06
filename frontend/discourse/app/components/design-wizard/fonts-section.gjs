import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { MAIN_FONTS, MORE_FONTS } from "discourse/admin/lib/constants";
import DMenu from "discourse/float-kit/components/d-menu";
import { fontClass } from "discourse/lib/design-wizard-preview";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ALL_FONTS = [...MAIN_FONTS, ...MORE_FONTS];

const FontTrigger = <template>
  <button class="btn btn-default btn-icon-text" type="button" ...attributes>
    <span class="d-button-label {{fontClass @fontKey}}">{{@label}}</span>
    {{dIcon "angle-down" class="design-wizard__font-select-caret"}}
  </button>
</template>;

export default class DesignWizardFontsSection extends Component {
  get baseFontLabel() {
    return this.#fontName(this.args.bodyFont);
  }

  get headingFontLabel() {
    return this.#fontName(this.args.headingFont);
  }

  #fontName(selectedKey) {
    return (
      ALL_FONTS.find((font) => font.key === selectedKey)?.name ?? selectedKey
    );
  }

  @action
  async selectFont(onSelect, fontKey, dMenu) {
    await dMenu.close();
    onSelect(fontKey);
  }

  <template>
    <div class="design-wizard__font-group">
      <span class="design-wizard__label">
        {{i18n "design_wizard.fonts.base_font"}}
      </span>
      <DMenu
        @identifier="design-wizard-base-font"
        @triggerClass="design-wizard__font-select"
        @contentClass="design-wizard__font-select-content"
        @modalForMobile={{true}}
        @triggerComponent={{component
          FontTrigger
          label=this.baseFontLabel
          fontKey=@bodyFont
        }}
      >
        <:content as |dMenu|>
          <DDropdownMenu class="design-wizard__font-list" as |dropdown|>
            {{#each ALL_FONTS as |font|}}
              <dropdown.item>
                <DButton
                  @action={{fn
                    this.selectFont
                    @onSelectBodyFont
                    font.key
                    dMenu
                  }}
                  @translatedLabel={{font.name}}
                  class="btn-flat
                    {{fontClass font.key}}
                    {{if (eq font.key @bodyFont) '-selected'}}"
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>

    <div class="design-wizard__font-group">
      <span class="design-wizard__label">
        {{i18n "design_wizard.fonts.heading_font"}}
      </span>
      <DMenu
        @identifier="design-wizard-heading-font"
        @triggerClass="design-wizard__font-select"
        @contentClass="design-wizard__font-select-content"
        @modalForMobile={{true}}
        @triggerComponent={{component
          FontTrigger
          label=this.headingFontLabel
          fontKey=@headingFont
        }}
      >
        <:content as |dMenu|>
          <DDropdownMenu class="design-wizard__font-list" as |dropdown|>
            {{#each ALL_FONTS as |font|}}
              <dropdown.item>
                <DButton
                  @action={{fn
                    this.selectFont
                    @onSelectHeadingFont
                    font.key
                    dMenu
                  }}
                  @translatedLabel={{font.name}}
                  class="btn-flat
                    {{fontClass font.key}}
                    {{if (eq font.key @headingFont) '-selected'}}"
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    </div>
  </template>
}
