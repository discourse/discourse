import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import cookie from "discourse/lib/cookie";
import DMenu from "float-kit/components/d-menu";

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

    this.dMenu.close();
    // content should switch immediately,
    // but we need a hard refresh here for controls to switch to the new locale
    window.location.reload();
  }

  get content() {
    return this.siteSettings.available_content_localization_locales.map(
      ({ value }) => ({
        name: this.languageNameLookup.getLanguageName(value),
        value,
      })
    );
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
          {{#each this.content as |option|}}
            <dropdown.item
              class="locale-options"
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
