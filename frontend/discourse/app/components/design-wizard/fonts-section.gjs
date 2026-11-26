import Component from "@glimmer/component";
import { fn, uniqueId } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { MAIN_FONTS, MORE_FONTS } from "discourse/admin/lib/constants";
import DMenu from "discourse/float-kit/components/d-menu";
import { fontClass } from "discourse/lib/design-wizard-preview";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectFont from "discourse/ui-kit/select/recipes/fonts/d-select-font";
import { i18n } from "discourse-i18n";

const ALL_FONTS = [...MAIN_FONTS, ...MORE_FONTS];

const FontTrigger = <template>
  <button class="btn btn-default btn-icon-text" type="button" ...attributes>
    <span class="d-button-label {{fontClass @fontKey}}">{{@label}}</span>
    {{dIcon "angle-down" class="design-wizard__font-select-caret"}}
  </button>
</template>;

export default class DesignWizardFontsSection extends Component {
  @service siteSettings;

  get baseFontLabel() {
    return this.#fontName(this.args.bodyFont);
  }

  get headingFontLabel() {
    return this.#fontName(this.args.headingFont);
  }

  @action
  async selectFont(onSelect, fontKey, dMenu) {
    await dMenu.close();
    onSelect(fontKey);
  }

  #fontName(selectedKey) {
    return (
      ALL_FONTS.find((font) => font.key === selectedKey)?.name ?? selectedKey
    );
  }

  <template>
    <div class="design-wizard__font-group">
      {{#let (uniqueId) as |labelId|}}
        <span class="design-wizard__label" id={{labelId}}>
          {{i18n "design_wizard.fonts.base_font"}}
        </span>
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectFont
            class="design-wizard__font-picker"
            @ariaLabelledBy={{labelId}}
            @ariaRequired={{true}}
            @clearMode="never"
            @contentClass="design-wizard__font-select-content"
            @fonts={{ALL_FONTS}}
            @onChange={{@onSelectBodyFont}}
            @sortByName={{false}}
            @value={{@bodyFont}}
            @valueField="key"
          />
        {{else}}
          <DMenu
            @contentClass="design-wizard__font-select-content"
            @identifier="design-wizard-base-font"
            @modalForMobile={{true}}
            @triggerClass="design-wizard__font-select"
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
                      class="btn-flat
                        {{fontClass font.key}}
                        {{if (eq font.key @bodyFont) '-selected'}}"
                      @action={{fn
                        this.selectFont
                        @onSelectBodyFont
                        font.key
                        dMenu
                      }}
                      @translatedLabel={{font.name}}
                    />
                  </dropdown.item>
                {{/each}}
              </DDropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      {{/let}}
    </div>

    <div class="design-wizard__font-group">
      {{#let (uniqueId) as |labelId|}}
        <span class="design-wizard__label" id={{labelId}}>
          {{i18n "design_wizard.fonts.heading_font"}}
        </span>
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectFont
            class="design-wizard__font-picker"
            @ariaLabelledBy={{labelId}}
            @ariaRequired={{true}}
            @clearMode="never"
            @contentClass="design-wizard__font-select-content"
            @fonts={{ALL_FONTS}}
            @onChange={{@onSelectHeadingFont}}
            @sortByName={{false}}
            @value={{@headingFont}}
            @valueField="key"
          />
        {{else}}
          <DMenu
            @contentClass="design-wizard__font-select-content"
            @identifier="design-wizard-heading-font"
            @modalForMobile={{true}}
            @triggerClass="design-wizard__font-select"
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
                      class="btn-flat
                        {{fontClass font.key}}
                        {{if (eq font.key @headingFont) '-selected'}}"
                      @action={{fn
                        this.selectFont
                        @onSelectHeadingFont
                        font.key
                        dMenu
                      }}
                      @translatedLabel={{font.name}}
                    />
                  </dropdown.item>
                {{/each}}
              </DDropdownMenu>
            </:content>
          </DMenu>
        {{/if}}
      {{/let}}
    </div>
  </template>
}
