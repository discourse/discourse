import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classify, decamelize, underscore } from "@ember/string";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import { MAIN_FONTS, MORE_FONTS } from "admin/lib/constants";
import eq from "truth-helpers/helpers/eq";

export default class AdminBrandingFontChooser extends Component {
  @tracked showMoreFonts = MORE_FONTS.includes(
    classify(this.args.selectedFont)
  );

  @action
  setButtonValue(fieldSet, value) {
    fieldSet(decamelize(underscore(value)));
  }

  @action
  toggleMoreFonts() {
    this.showMoreFonts = !this.showMoreFonts;
  }

  <template>
    <@field.Custom>
      {{#each MAIN_FONTS as |font|}}
        <DButton
          @action={{fn this.setButtonValue @field.set font}}
          class={{concatClass
            "admin-fonts-form__button-option font btn-flat"
            (decamelize (underscore font))
            (if (eq @selectedFont (decamelize (underscore font))) "active")
          }}
        >{{font}}</DButton>
      {{/each}}
      {{#if this.showMoreFonts}}
        {{#each MORE_FONTS as |font|}}
          <DButton
            @action={{fn this.setButtonValue @field.set font}}
            class={{concatClass
              "admin-fonts-form__button-option font btn-flat"
              (decamelize (underscore font))
              (if (eq @selectedFont (decamelize (underscore font))) "active")
            }}
          >{{font}}</DButton>
        {{/each}}
      {{/if}}
      <DButton
        @action={{this.toggleMoreFonts}}
        class="admin-fonts-form__more font"
      >
        {{#if this.showMoreFonts}}
          {{i18n "admin.config.branding.fonts.form.less_fonts"}}
        {{else}}
          {{i18n "admin.config.branding.fonts.form.more_fonts"}}
        {{/if}}
      </DButton>
    </@field.Custom>
  </template>
}
