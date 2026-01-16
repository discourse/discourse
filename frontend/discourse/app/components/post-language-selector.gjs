import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";

export default class PostLanguageSelector extends Component {
  @service siteSettings;
  @service languageNameLookup;

  get selectedLanguage() {
    return (
      this.siteSettings.available_content_localization_locales.find(
        (locale) => locale.value === this.args.composerModel.locale
      )?.value || ""
    );
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
  selectPostLanguage(locale) {
    this.args.composerModel.locale = locale;
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <DMenu
      @identifier="post-language-selector"
      @title={{i18n "post.localizations.post_language_selector.title"}}
      @icon="globe"
      @label={{this.selectedLanguage}}
      @modalForMobile={{true}}
      @onRegisterApi={{this.onRegisterApi}}
      @class="btn-transparent btn-small post-language-selector"
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.content as |locale|}}
            <dropdown.item
              class="locale-options"
              data-menu-option-id={{locale.value}}
            >
              <DButton
                @translatedLabel={{locale.name}}
                @title={{locale.value}}
                @action={{fn this.selectPostLanguage locale.value}}
              />
            </dropdown.item>
          {{/each}}
          <dropdown.divider />
          <dropdown.item>
            <DButton
              @label="post.localizations.post_language_selector.none"
              @action={{fn this.selectPostLanguage null}}
            />
          </dropdown.item>
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
