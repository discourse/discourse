import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "float-kit/components/d-menu";

export default class PostLanguageSelector extends Component {
  @service postLocalization;
  @service siteSettings;

  // @tracked postLocale = null;

  get selectedLanguage() {
    if (this.args.composerModel.locale) {
      return this.args.composerModel.locale;
    }

    return this.siteSettings.default_locale;
  }

  @action
  selectPostLanguage(locale) {
    // this.postLocale = locale;
    this.args.composerModel.locale = locale;
    console.log(this.args.composerModel);
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <DMenu
      @identifier="post-language-selector"
      @title="Post Language"
      @icon="globe"
      @label={{this.selectedLanguage}}
      @modalForMobile={{true}}
      @onRegisterApi={{this.onRegisterApi}}
      @class="btn-transparent"
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{log @composerModel}}
          {{#each this.postLocalization.availableLocales as |locale|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{locale.name}}
                @title={{locale.value}}
                @action={{fn this.selectPostLanguage locale.value}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
