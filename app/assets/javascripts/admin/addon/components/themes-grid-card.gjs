import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";

export default class ThemeCard extends Component {
  @service siteSettings;

  get buttonIcon() {
    return this.isDefault ? "far-check-square" : "far-square";
  }

  get buttonTitle() {
    return this.args.theme.default
      ? "admin.customize.theme.default_theme"
      : "admin.customize.theme.set_default_theme";
  }

  get buttonClasses() {
    return this.isDefault
      ? "btn-primary theme-card-button"
      : "btn-default theme-card-button";
  }

  get isDefault() {
    return this.args.theme.default;
  }

  get image_alt() {
    return this.args.theme.name;
  }

  get screenshot() {
    return this.args.theme.screenshot
      ? this.args.theme.screenshot
      : "https://picsum.photos/200/300";
  }

  @action
  setDefault() {
    // Make this theme default theme -> https://github.com/discourse/discourse/blob/24caa36eef826bcdaed88aebfa7df154413fb349/app/assets/javascripts/admin/addon/controllers/admin-customize-themes-show.js#L366
  }

  @action
  showPreview() {
    // bring admin to theme preview of site
  }

  get themeRouteModels() {
    return ["themes", this.args.theme.id];
  }

  <template>
    <AdminConfigAreaCard @translatedHeading={{this.args.theme.name}} class={{concatClass "theme-card" (if this.isDefault "--active" "")}}>
      <div class="theme-card-image-wrapper">
        <div class="">
        </div>
        <img class="theme-card-image" src={{htmlSafe this.screenshot}} alt={{this.image_alt}} />
      </div>
      <div class="theme-card-content">
        <p class="theme-card-description">{{this.args.theme.description}}</p>
        <img
          class="theme-card-image"
          src={{htmlSafe this.screenshot}}
          alt={{this.image_alt}}
        />
      </div>
      <div class="theme-card-content">
        <h2 class="theme-card-title">{{@theme.name}}</h2>
        <p class="theme-card-description">{{@theme.description}}</p>
      </div>
      <div class="theme-card-footer">
        <DButton
          @action={{this.setDefault}}
          @preventFocus={{true}}
          @icon={{this.buttonIcon}}
          @class={{this.buttonClasses}}
          @translatedLabel={{i18n this.buttonTitle}}
          @disabled={{this.isDefault}}
        />
        <div class="theme-card-footer-actions">
          <DButton
            @action={{this.showPreview}}
            @icon="eye"
            @class="btn-flat theme-card-button"
            @preventFocus={{true}}
          />
          <DButton
            @route="adminCustomizeThemes.show"
            @routeModels={{this.themeRouteModels}}
            @icon="cog"
            @class="btn-flat theme-card-button"
            @preventFocus={{true}}
          />
        </div>
      </div>
    </AdminConfigAreaCard>
    {{!-- </div> --}}
  </template>
}
