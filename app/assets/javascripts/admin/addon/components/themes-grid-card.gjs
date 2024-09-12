import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";

export default class ThemeCard extends Component {
  @service siteSettings;
  @service toasts;
  @tracked isDefault = this.args.theme.default;

  get buttonIcon() {
    return this.isDefault ? "far-check-square" : "far-square";
  }

  get buttonTitle() {
    return this.isDefault
      ? "admin.customize.theme.default_theme"
      : "admin.customize.theme.set_default_theme";
  }

  get buttonClasses() {
    return this.isDefault
      ? "btn-primary theme-card-button"
      : "btn-default theme-card-button";
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
  async setDefault() {
    // currently saves the correct theme default, but does not update the UI
    this.args.theme.set("default", true);
    this.args.theme.saveChanges("default").then(() => {
      if (this.args.theme.get("default")) {
        this.args.allThemes.forEach((theme) => {
          if (theme !== theme.get("default")) {
            theme.set("default", false);
          }
        });
      }
      this.toasts.success({
        data: {message: I18n.t("admin.customize.theme.set_default_success", {theme: this.args.theme.name})},
        duration: 2000,
      });
    });
    // inspired by -> https://github.com/discourse/discourse/blob/24caa36eef826bcdaed88aebfa7df154413fb349/app/assets/javascripts/admin/addon/controllers/admin-customize-themes-show.js#L366
  }

  @action
  showPreview() {
    // bring admin to theme preview of site
  }

  @action
  async handleSubmit(event) {
    this.args.theme.set("user_selectable", event.target.checked);
    this.args.theme.saveChanges("user_selectable");
  }

  get themeRouteModels() {
    return ["themes", this.args.theme.id];
  }

  <template>
    <AdminConfigAreaCard
      @translatedHeading={{this.args.theme.name}}
      class={{concatClass "theme-card" (if this.isDefault "--active" "")}}
    >
      <div class="theme-card-image-wrapper">
        <div class="theme-card-user-selectable">
          <Input
            @type="checkbox"
            @checked={{this.args.theme.user_selectable}}
            id="user-select-theme-{{this.args.theme.id}}"
            onclick={{this.handleSubmit}}
          />
          <label class="checkbox-label" for="user-select-theme-{{this.args.theme.id}}">
            {{i18n "admin.config_areas.themes.user_selectable"}}
          </label>
        </div>
        <img
          class="theme-card-image"
          src={{htmlSafe this.screenshot}}
          alt={{this.image_alt}}
        />
      </div>
      <div class="theme-card-content">
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
  </template>
}
