import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { dasherize } from "@ember/string";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import { MAIN_FONTS, MORE_FONTS } from "admin/lib/constants";

export default class AdminFontChooser extends Component {
  @tracked showMoreFonts = MORE_FONTS.map((font) => font.key).includes(
    this.args.selectedFont
  );

  @action
  setButtonValue(fieldSet, value) {
    fieldSet(value);
  }

  @action
  toggleMoreFonts() {
    this.showMoreFonts = !this.showMoreFonts;
  }

  <template>
    <@field.Custom>
      {{#each MAIN_FONTS as |font|}}
        <DButton
          @action={{fn this.setButtonValue @field.set font.key}}
          class={{concatClass
            "admin-fonts-form__button-option font btn-flat"
            (concat "body-font-" (dasherize font.key))
            (if (eq @selectedFont font.key) "active")
          }}
        >{{font.name}}</DButton>
      {{/each}}
      {{#if this.showMoreFonts}}
        {{#each MORE_FONTS as |font|}}
          <DButton
            @action={{fn this.setButtonValue @field.set font.key}}
            class={{concatClass
              "admin-fonts-form__button-option font btn-flat"
              (concat "body-font-" (dasherize font.key))
              (if (eq @selectedFont font.key) "active")
            }}
          >{{font.name}}</DButton>
        {{/each}}
      {{/if}}
      <DButton
        @action={{this.toggleMoreFonts}}
        class="admin-fonts-form__more font"
      >
        {{#if this.showMoreFonts}}
          {{i18n "admin.config.fonts.form.fewer_fonts"}}
        {{else}}
          {{i18n "admin.config.fonts.form.more_fonts"}}
        {{/if}}
      </DButton>
    </@field.Custom>
  </template>
}
