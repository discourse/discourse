import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import cookie, { removeCookie } from "discourse/lib/cookie";
import I18n, { i18n } from "discourse-i18n";

const SHOW_ORIGINAL_COOKIE = "content-localization-show-original";

export default class LanguageSwitcher extends Component {
  @service siteSettings;
  @service languageNameLookup;
  @service currentUser;

  @action
  async changeLocale(locale) {
    if (this.currentUser) {
      this.currentUser.set("locale", locale);
      await this.currentUser.save(["locale"]);
    } else {
      cookie("locale", locale, { path: "/" });
    }

    removeCookie(SHOW_ORIGINAL_COOKIE, { path: "/" });

    this.dMenu.close();
    // content should switch immediately,
    // but we need a hard refresh here for controls to switch to the new locale
    window.location.reload();
  }

  get currentLocale() {
    return I18n.locale;
  }

  get currentLanguageCode() {
    return this.currentLocale.split("_")[0].toUpperCase();
  }

  get content() {
    const langs = this.siteSettings.available_content_localization_locales.map(
      ({ value }) => ({
        name: this.languageNameLookup.getLanguageName(value),
        value,
        isActive: value === this.currentLocale,
      })
    );

    // Cleanup "English" name when `en_GB` is the only English variant
    if (!langs.find((lang) => lang.value === "en")) {
      const ukLang = langs.find((lang) => lang.value === "en_GB");
      if (ukLang) {
        ukLang.name = this.normalizeUKEnglish(ukLang.name);
      }
    }

    // Cleanup "Português" name when `pt_BR` is the only variant
    if (!langs.find((lang) => lang.value === "pt")) {
      const ptbrName = langs.find((lang) => lang.value === "pt_BR");
      if (ptbrName) {
        ptbrName.name = ptbrName.name.replace(" (BR)", "").trim();
      }
    }

    return langs;
  }

  normalizeUKEnglish(text) {
    // strip all variants of "English (region)"
    let result = text.replace("(English (UK))", "");
    result = result
      .replace(/\s*\([^)]*\)/g, "")
      .replace(/\s+/g, " ")
      .trim();

    // Add back "(English)"
    if (text.includes("English") && !result.match(/^English/i)) {
      result += " (English)";
    }

    return result;
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <DMenu
      @identifier="language-switcher"
      @title={{i18n "language_switcher.title"}}
      class="btn-flat"
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:trigger>
        <span class="language-switcher__locale">
          {{this.currentLanguageCode}}
        </span>
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.content as |option|}}
            <dropdown.item
              class="locale-options {{if option.isActive '--selected'}}"
              data-menu-option-id={{option.value}}
            >
              <DButton
                @translatedLabel={{option.name}}
                @action={{fn this.changeLocale option.value}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
