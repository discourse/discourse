import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import cookie from "discourse/lib/cookie";
import DMenu from "float-kit/components/d-menu";

export default class LanguageSwitcher extends Component {
  @service site;
  @service siteSettings;
  @service router;

  get localeOptions() {
    const targetLanguages = (
      this.siteSettings.experimental_content_localization_supported_locales ||
      ""
    ).split("|");
    return JSON.parse(this.siteSettings.available_locales)
      .filter(({ value }) => targetLanguages.includes(value))
      .map(({ name, value }) => {
        return {
          label: name,
          value,
        };
      });
  }

  @action
  async changeLocale(locale) {
    cookie("locale", locale, { path: "/" });
    this.dMenu.close();
    // we need a hard refresh here for the locale to take effect
    // window.location.reload();
    this.router.refresh();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <DMenu
      @identifier="language-switcher"
      title="Language switcher"
      @icon="language"
      class="btn-flat btn-icon icon"
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.localeOptions as |option|}}
            <dropdown.item
              class="locale-options"
              data-menu-option-id={{option.value}}
            >
              <DButton
                @translatedLabel={{option.label}}
                @action={{fn this.changeLocale option.value}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
